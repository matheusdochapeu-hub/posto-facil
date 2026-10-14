import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/ocr_service.dart';
import '../models/gas_station.dart';
import '../models/price_record.dart';

/// Tela para registrar um novo preço de combustível
class RegisterPriceScreen extends StatefulWidget {
  const RegisterPriceScreen({super.key});

  @override
  State<RegisterPriceScreen> createState() => _RegisterPriceScreenState();
}

class _RegisterPriceScreenState extends State<RegisterPriceScreen> {
  // Serviços
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _ocrService = OcrService();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  // Estado da tela
  File? _selectedImage;       // Foto tirada pelo usuário
  bool _isProcessingOcr = false;  // Está lendo a foto?
  bool _isSaving = false;         // Está salvando?

  // Controladores dos campos de texto
  final _stationNameController = TextEditingController();
  final _gasolineCommonController = TextEditingController();
  final _gasolinePremiumController = TextEditingController();
  final _ethanolController = TextEditingController();
  final _dieselController = TextEditingController();
  final _promotionController = TextEditingController();

  bool _hasPromotion = false;  // Tem promoção?
  Position? _currentPosition;  // Posição GPS atual
  String _addressText = 'Obtendo localização...';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// Obtém a localização atual do usuário
  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _currentPosition = position;
        _addressText = address;
      });
    } else if (mounted) {
      setState(() => _addressText = 'Localização não disponível');
    }
  }

  /// Abre a câmera para tirar uma foto
  Future<void> _takePicture() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,  // 85% de qualidade (bom equilíbrio tamanho/qualidade)
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _isProcessingOcr = true;
      });

      await _processImageWithOcr(File(photo.path));
    }
  }

  /// Abre a galeria para escolher uma foto
  Future<void> _pickFromGallery() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _isProcessingOcr = true;
      });

      await _processImageWithOcr(File(photo.path));
    }
  }

  /// Processa a foto com OCR para extrair os preços automaticamente
  Future<void> _processImageWithOcr(File imageFile) async {
    try {
      final result = await _ocrService.extractPricesFromImage(imageFile);

      if (mounted) {
        setState(() {
          _isProcessingOcr = false;

          // Preenche os campos com os valores encontrados na foto
          if (result.gasolineCommon != null) {
            _gasolineCommonController.text =
                result.gasolineCommon!.toStringAsFixed(2);
          }
          if (result.gasolinePremium != null) {
            _gasolinePremiumController.text =
                result.gasolinePremium!.toStringAsFixed(2);
          }
          if (result.ethanol != null) {
            _ethanolController.text = result.ethanol!.toStringAsFixed(2);
          }
          if (result.diesel != null) {
            _dieselController.text = result.diesel!.toStringAsFixed(2);
          }
          _hasPromotion = result.hasPromotion;
        });

        // Avisa que preencheu automaticamente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '✅ Preços detectados automaticamente! Confirme se estão corretos.'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Não consegui ler os preços. Por favor, preencha manualmente.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Salva o registro de preço no Firebase
  Future<void> _saveRecord() async {
    // Validação básica
    if (_stationNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe o nome do posto.')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Localização não disponível. Ative o GPS e tente novamente.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Verifica se já existe um posto nessa localização
      GasStation? station = await _firestoreService.findStationNearCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      // Se não existe, cria um novo posto
      if (station == null) {
        final newStation = GasStation(
          id: '',
          name: _stationNameController.text.trim(),
          address: _addressText,
          location: GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );

        final stationId = await _firestoreService.createStation(newStation);
        station = await _firestoreService.getStationById(stationId);
      }

      // Faz upload da foto (se houver)
      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await _firestoreService.uploadPricePhoto(
          imageFile: _selectedImage!,
          stationId: station!.id,
          userId: _authService.userId,
        );
      }

      // Parseia os preços dos campos de texto
      final gasolineCommon = double.tryParse(
        _gasolineCommonController.text.replaceAll(',', '.'),
      );
      final gasolinePremium = double.tryParse(
        _gasolinePremiumController.text.replaceAll(',', '.'),
      );
      final ethanol = double.tryParse(
        _ethanolController.text.replaceAll(',', '.'),
      );
      final diesel = double.tryParse(
        _dieselController.text.replaceAll(',', '.'),
      );

      // Salva o registro de preço
      final record = PriceRecord(
        id: '',
        stationId: station!.id,
        userId: _authService.userId,
        userName: _authService.displayName,
        gasolineCommon: gasolineCommon,
        gasolinePremium: gasolinePremium,
        ethanol: ethanol,
        diesel: diesel,
        hasPromotion: _hasPromotion,
        promotionDescription: _hasPromotion
            ? _promotionController.text.trim()
            : null,
        photoUrl: photoUrl,
        recordedAt: DateTime.now(),
        recordedLocation: GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
      );

      await _firestoreService.savePriceRecord(record);

      // Atualiza os preços do posto
      await _firestoreService.updateStationPrices(
        stationId: station.id,
        gasolineCommon: gasolineCommon,
        gasolinePremium: gasolinePremium,
        ethanol: ethanol,
        diesel: diesel,
        hasPromotion: _hasPromotion,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Preço registrado com sucesso! Obrigado!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context); // Volta para a tela inicial
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _gasolineCommonController.dispose();
    _gasolinePremiumController.dispose();
    _ethanolController.dispose();
    _dieselController.dispose();
    _promotionController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Preço'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Seção: Foto ───────────────────────────────
            _SectionTitle(title: '📸 Foto da Tabela de Preços'),
            const Text(
              'Tire uma foto clara da tabela de preços do posto. Os preços serão preenchidos automaticamente!',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Área da foto
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedImage != null
                        ? const Color(0xFF2E7D32)
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: _isProcessingOcr
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Lendo preços da foto...'),
                        ],
                      )
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Toque para tirar uma foto',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Seção: Informações do posto ──────────────
            _SectionTitle(title: '🏪 Informações do Posto'),

            // Nome do posto
            TextField(
              controller: _stationNameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Posto *',
                hintText: 'Ex: Posto Shell Avenida',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Localização (automática)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _addressText,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _getCurrentLocation,
                    child: const Text('Atualizar'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Seção: Preços ────────────────────────────
            _SectionTitle(title: '💰 Preços (R\$)'),
            const Text(
              'Preencha os preços que você viu. Deixe em branco os que não estiverem disponíveis.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Grid de preços 2x2
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: _gasolineCommonController,
                    label: 'Gasolina Comum',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PriceField(
                    controller: _gasolinePremiumController,
                    label: 'Gasolina Aditivada',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: _ethanolController,
                    label: 'Álcool / Etanol',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PriceField(
                    controller: _dieselController,
                    label: 'Diesel',
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Seção: Promoção ──────────────────────────
            _SectionTitle(title: '🎯 Promoção'),
            Row(
              children: [
                Switch(
                  value: _hasPromotion,
                  onChanged: (value) => setState(() => _hasPromotion = value),
                  activeColor: const Color(0xFF2E7D32),
                ),
                const Text('Possui promoção ativa'),
              ],
            ),

            if (_hasPromotion) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _promotionController,
                decoration: const InputDecoration(
                  labelText: 'Descreva a promoção',
                  hintText: 'Ex: 5% de desconto no débito',
                  prefixIcon: Icon(Icons.local_offer),
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ─── Botão Salvar ─────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecord,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isSaving ? 'Salvando...' : 'Registrar Preço'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Mostra diálogo para escolher câmera ou galeria
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar Foto'),
              onTap: () {
                Navigator.pop(context);
                _takePicture();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da Galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de seção
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }
}

/// Campo de preço formatado
class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;

  const _PriceField({
    required this.controller,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'R\$ ',
        prefixStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}

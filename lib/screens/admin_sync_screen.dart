import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/anp_service.dart';

/// Tela de administração — sincroniza os postos da ANP com o banco de dados
/// Acessível pelo menu de configurações (apenas para o administrador do app)
class AdminSyncScreen extends StatefulWidget {
  const AdminSyncScreen({super.key});

  @override
  State<AdminSyncScreen> createState() => _AdminSyncScreenState();
}

class _AdminSyncScreenState extends State<AdminSyncScreen> {
  final _anpService = AnpService();
  bool _isLoading = false;
  SyncResult? _lastResult;
  String _statusMessage = 'Pronto para sincronizar.';
  List<AnpStation> _previewStations = [];
  bool _isPreviewing = false;

  /// Busca uma prévia dos postos da ANP antes de sincronizar
  Future<void> _previewAnpData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Buscando dados na API da ANP...';
      _previewStations = [];
    });

    try {
      final stations = await _anpService.fetchStationsFromAnp();
      final withLocation = stations.where((s) => s.hasLocation).length;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPreviewing = true;
          _previewStations = stations;
          _statusMessage =
              '✅ ${stations.length} postos encontrados em Ribeirão Preto.\n'
              '$withLocation possuem coordenadas GPS e serão importados.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '❌ Erro ao acessar API da ANP: $e';
        });
      }
    }
  }

  /// Sincroniza os dados da ANP com o Firestore
  Future<void> _syncWithFirestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Sincronizando com o banco de dados...';
    });

    try {
      final result =
          await _anpService.syncWithFirestore(FirebaseFirestore.instance);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastResult = result;
          _statusMessage = '🎉 Sincronização concluída!\n'
              '• ${result.total} postos encontrados na ANP\n'
              '• ${result.created} novos postos importados\n'
              '• ${result.skipped} ignorados (já existiam ou sem GPS)\n'
              '• ${result.errors} erros';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '❌ Erro na sincronização: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronizar Postos ANP'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explicação
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'O que é isso?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A ANP (Agência Nacional do Petróleo) mantém um cadastro '
                    'oficial de todos os postos autorizados no Brasil. '
                    'Esta tela importa automaticamente todos os postos '
                    'de Ribeirão Preto para o banco de dados do app.\n\n'
                    'Faça isso apenas uma vez ao lançar o app, e depois '
                    'periodicamente para incluir postos novos.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'API: revendedoresapi.anp.gov.br',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status atual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('Processando...')),
                      ],
                    )
                  else
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _previewAnpData,
                    icon: const Icon(Icons.preview),
                    label: const Text('Ver Prévia'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _syncWithFirestore,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sincronizar'),
                  ),
                ),
              ],
            ),

            // Lista de postos encontrados na prévia
            if (_isPreviewing && _previewStations.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Postos encontrados (${_previewStations.length}):',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _previewStations.length,
                itemBuilder: (context, index) {
                  final station = _previewStations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.local_gas_station,
                        color: station.hasLocation
                            ? Colors.green
                            : Colors.grey,
                        size: 20,
                      ),
                      title: Text(
                        station.razaoSocial,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${station.bairro} • ${station.distribuidora}'
                        '${station.hasLocation ? '' : ' • ⚠️ Sem GPS'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: station.hasLocation
                          ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 16)
                          : const Icon(Icons.location_off,
                              color: Colors.grey, size: 16),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

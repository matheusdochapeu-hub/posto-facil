import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/gas_station.dart';
import '../models/price_record.dart';
import '../services/firestore_service.dart';

/// Tela de detalhes de um posto de gasolina
class StationDetailScreen extends StatefulWidget {
  final GasStation station;

  const StationDetailScreen({super.key, required this.station});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  final _firestoreService = FirestoreService();
  List<PriceRecord> _priceHistory = [];
  bool _isLoadingHistory = true;

  // Formatadores de data e moeda em português brasileiro
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
  }

  Future<void> _loadPriceHistory() async {
    final history = await _firestoreService.getRecentPricesForStation(
      widget.station.id,
      limit: 5,
    );

    if (mounted) {
      setState(() {
        _priceHistory = history;
        _isLoadingHistory = false;
      });
    }
  }

  /// Abre o Google Maps com a rota até o posto
  Future<void> _openInGoogleMaps() async {
    final lat = widget.station.latitude;
    final lng = widget.station.longitude;
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o Maps.')),
        );
      }
    }
  }

  /// Formata a data de atualização de forma amigável
  String _formatLastUpdated(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} minutos';
    } else if (diff.inHours < 24) {
      return 'Há ${diff.inHours} horas';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      return 'Há ${diff.inDays} dias';
    } else {
      return _dateFormat.format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;

    return Scaffold(
      appBar: AppBar(
        title: Text(station.name, overflow: TextOverflow.ellipsis),
        actions: [
          // Botão "Como chegar"
          TextButton.icon(
            onPressed: _openInGoogleMaps,
            icon: const Icon(Icons.directions, color: Colors.white),
            label: const Text('Como chegar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Cabeçalho verde ─────────────────────────
            Container(
              width: double.infinity,
              color: const Color(0xFF2E7D32),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          station.address,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.update, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Atualizado ${_formatLastUpdated(station.lastUpdated)}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  if (station.hasPromotion) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_offer,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'PROMOÇÃO ATIVA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Preços atuais ──────────────────────
                  const Text(
                    '💰 Preços Atuais',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid de preços 2x2
                  Row(
                    children: [
                      Expanded(
                        child: _PriceCard(
                          label: 'Gasolina\nComum',
                          price: station.gasolineCommon,
                          color: Colors.orange,
                          icon: Icons.local_gas_station,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceCard(
                          label: 'Gasolina\nAditivada',
                          price: station.gasolinePremium,
                          color: Colors.red,
                          icon: Icons.star,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceCard(
                          label: 'Álcool /\nEtanol',
                          price: station.ethanol,
                          color: Colors.green,
                          icon: Icons.eco,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceCard(
                          label: 'Diesel',
                          price: station.diesel,
                          color: Colors.blueGrey,
                          icon: Icons.fire_truck,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Histórico de registros ─────────────
                  const Text(
                    '📋 Histórico de Preços',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Últimos 5 registros enviados por usuários',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  _isLoadingHistory
                      ? const Center(child: CircularProgressIndicator())
                      : _priceHistory.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Nenhum registro de preço ainda.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _priceHistory.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final record = _priceHistory[index];
                                return _PriceHistoryTile(
                                  record: record,
                                  dateFormat: _dateFormat,
                                );
                              },
                            ),

                  const SizedBox(height: 24),

                  // ─── Botão Como Chegar ─────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInGoogleMaps,
                      icon: const Icon(Icons.directions),
                      label: const Text('Como Chegar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de preço individual
class _PriceCard extends StatelessWidget {
  final String label;
  final double? price;
  final Color color;
  final IconData icon;

  const _PriceCard({
    required this.label,
    required this.price,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: price != null ? color.withOpacity(0.08) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: price != null ? color.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: price != null ? color : Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: price != null ? color : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price != null ? 'R\$ ${price!.toStringAsFixed(2)}' : '—',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: price != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha do histórico de preços
class _PriceHistoryTile extends StatelessWidget {
  final PriceRecord record;
  final DateFormat dateFormat;

  const _PriceHistoryTile({
    required this.record,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                record.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                dateFormat.format(record.recordedAt),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (record.gasolineCommon != null)
                _PriceChip(
                  label: 'Comum',
                  price: record.gasolineCommon!,
                  color: Colors.orange,
                ),
              if (record.gasolinePremium != null)
                _PriceChip(
                  label: 'Aditivada',
                  price: record.gasolinePremium!,
                  color: Colors.red,
                ),
              if (record.ethanol != null)
                _PriceChip(
                  label: 'Álcool',
                  price: record.ethanol!,
                  color: Colors.green,
                ),
              if (record.diesel != null)
                _PriceChip(
                  label: 'Diesel',
                  price: record.diesel!,
                  color: Colors.blueGrey,
                ),
            ],
          ),
          if (record.hasPromotion && record.promotionDescription != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.local_offer, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  record.promotionDescription!,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip pequeno de preço
class _PriceChip extends StatelessWidget {
  final String label;
  final double price;
  final Color color;

  const _PriceChip({
    required this.label,
    required this.price,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: R\$ ${price.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          color: color.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

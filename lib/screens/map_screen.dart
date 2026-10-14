import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gas_station.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'station_detail_screen.dart';

/// Tela do mapa — mostra os postos próximos ao usuário
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Serviços
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();

  // Estado
  GoogleMapController? _mapController;
  Position? _userPosition;
  List<GasStation> _stations = [];
  Set<Marker> _markers = {};
  FuelType _selectedFuel = FuelType.gasolineCommon;
  bool _isLoading = true;
  bool _showList = false;  // Alternar entre mapa e lista

  // Centro de Ribeirão Preto (posição inicial do mapa)
  static const LatLng _ribeiraoPretoCentro = LatLng(-21.1767, -47.8208);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Obtém localização do usuário
    final position = await _locationService.getCurrentPosition();

    if (mounted) {
      setState(() {
        _userPosition = position;
      });
    }

    // Busca postos próximos
    await _loadNearbyStations(
      latitude: position?.latitude ?? _ribeiraoPretoCentro.latitude,
      longitude: position?.longitude ?? _ribeiraoPretoCentro.longitude,
    );
  }

  Future<void> _loadNearbyStations({
    required double latitude,
    required double longitude,
  }) async {
    setState(() => _isLoading = true);

    try {
      final stations = await _firestoreService.getNearbyStations(
        latitude: latitude,
        longitude: longitude,
        radiusKm: 15.0,
      );

      final markers = <Marker>{};

      for (final station in stations) {
        final price = station.getPriceFor(_selectedFuel);
        final priceText = price != null
            ? 'R\$ ${price.toStringAsFixed(2)}'
            : 'Sem preço';

        markers.add(
          Marker(
            markerId: MarkerId(station.id),
            position: LatLng(station.latitude, station.longitude),
            infoWindow: InfoWindow(
              title: station.name,
              snippet: '$priceText · Toque para detalhes',
              onTap: () => _openStationDetail(station),
            ),
            icon: await _getMarkerIcon(price),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _stations = stations;
          _markers = markers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar postos: $e')),
        );
      }
    }
  }

  /// Retorna o ícone do marcador com base no preço
  /// Verde = mais barato, Amarelo = médio, Vermelho = mais caro
  Future<BitmapDescriptor> _getMarkerIcon(double? price) async {
    if (price == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }

    // Define cor baseada no preço (em relação à média atual BR ~R$5,80)
    if (price < 5.50) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (price < 6.00) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  void _openStationDetail(GasStation station) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StationDetailScreen(station: station),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postos Próximos'),
        actions: [
          // Botão alternar entre mapa e lista
          IconButton(
            icon: Icon(_showList ? Icons.map : Icons.list),
            onPressed: () => setState(() => _showList = !_showList),
            tooltip: _showList ? 'Ver mapa' : 'Ver lista',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _FuelFilterBar(
            selectedFuel: _selectedFuel,
            onFuelSelected: (fuel) {
              setState(() => _selectedFuel = fuel);
              // Recarrega os marcadores com o novo combustível
              if (_userPosition != null) {
                _loadNearbyStations(
                  latitude: _userPosition!.latitude,
                  longitude: _userPosition!.longitude,
                );
              }
            },
          ),
        ),
      ),

      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buscando postos próximos...'),
                ],
              ),
            )
          : _showList
              ? _buildStationList()
              : _buildMap(),

      // Botão flutuante para centralizar no usuário
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_userPosition != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(_userPosition!.latitude, _userPosition!.longitude),
                15,
              ),
            );
          }
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _buildMap() {
    final initialPos = _userPosition != null
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : _ribeiraoPretoCentro;

    return GoogleMap(
      onMapCreated: (controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: initialPos,
        zoom: 14,
      ),
      markers: _markers,
      myLocationEnabled: true,           // Ponto azul na posição do usuário
      myLocationButtonEnabled: false,    // Usamos nosso próprio botão
      zoomControlsEnabled: false,        // Botões +/- (usamos gestos)
      mapToolbarEnabled: false,
    );
  }

  Widget _buildStationList() {
    if (_stations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum posto encontrado nessa região.',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Seja o primeiro a registrar um preço!',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Ordena por preço do combustível selecionado
    final sorted = List<GasStation>.from(_stations);
    sorted.sort((a, b) {
      final priceA = a.getPriceFor(_selectedFuel) ?? double.infinity;
      final priceB = b.getPriceFor(_selectedFuel) ?? double.infinity;
      return priceA.compareTo(priceB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final station = sorted[index];
        final price = station.getPriceFor(_selectedFuel);
        final distance = _userPosition != null
            ? _locationService.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                station.latitude,
                station.longitude,
              )
            : null;

        return _StationListCard(
          station: station,
          price: price,
          selectedFuel: _selectedFuel,
          distanceText: distance != null
              ? _locationService.formatDistance(distance)
              : null,
          isLowest: index == 0 && price != null,
          onTap: () => _openStationDetail(station),
        );
      },
    );
  }
}

/// Barra de filtro de combustível
class _FuelFilterBar extends StatelessWidget {
  final FuelType selectedFuel;
  final ValueChanged<FuelType> onFuelSelected;

  const _FuelFilterBar({
    required this.selectedFuel,
    required this.onFuelSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E7D32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: FuelType.values.map((fuel) {
            final isSelected = fuel == selectedFuel;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(fuel.label),
                selected: isSelected,
                onSelected: (_) => onFuelSelected(fuel),
                backgroundColor: Colors.white24,
                selectedColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                checkmarkColor: const Color(0xFF2E7D32),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Card de posto na lista
class _StationListCard extends StatelessWidget {
  final GasStation station;
  final double? price;
  final FuelType selectedFuel;
  final String? distanceText;
  final bool isLowest;
  final VoidCallback onTap;

  const _StationListCard({
    required this.station,
    required this.price,
    required this.selectedFuel,
    required this.distanceText,
    required this.isLowest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone do posto
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLowest ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_gas_station,
                  color: isLowest ? Colors.green : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),

              // Informações do posto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isLowest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MAIS BARATO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      station.address,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distanceText != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.near_me,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            distanceText!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                          if (station.hasPromotion) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.local_offer,
                                size: 12, color: Colors.orange),
                            const SizedBox(width: 2),
                            const Text(
                              'Promoção',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Preço
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price != null ? 'R\$ ${price.toStringAsFixed(2)}' : '—',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLowest ? Colors.green : Colors.black87,
                    ),
                  ),
                  Text(
                    selectedFuel.label.split('/').first.trim(),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

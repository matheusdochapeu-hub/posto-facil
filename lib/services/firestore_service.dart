import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/gas_station.dart';
import '../models/price_record.dart';

/// Serviço de banco de dados — comunicação com o Firebase Firestore
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Referências às coleções do banco de dados
  CollectionReference get _stations => _db.collection('gas_stations');
  CollectionReference get _prices => _db.collection('price_records');

  // ═══════════════════════════════════════════════════════
  // POSTOS DE GASOLINA
  // ═══════════════════════════════════════════════════════

  /// Busca postos próximos a uma localização
  /// [latitude] e [longitude] = posição do usuário
  /// [radiusKm] = raio de busca em quilômetros
  Future<List<GasStation>> getNearbyStations({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    // Firestore não tem busca geográfica nativa — usamos bounding box
    // (caixa de coordenadas ao redor do usuário)
    final double latDelta = radiusKm / 111.0; // ~111 km por grau de latitude
    final double lngDelta = radiusKm / (111.0 * 0.85); // ajuste para longitude

    final snapshot = await _stations
        .where('location',
            isGreaterThan: GeoPoint(latitude - latDelta, longitude - lngDelta))
        .where('location',
            isLessThan: GeoPoint(latitude + latDelta, longitude + lngDelta))
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => GasStation.fromFirestore(doc)).toList();
  }

  /// Busca todos os postos (para admin ou listagem geral)
  Stream<List<GasStation>> getAllStations() {
    return _stations
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GasStation.fromFirestore(doc)).toList());
  }

  /// Busca um posto específico pelo ID
  Future<GasStation?> getStationById(String id) async {
    final doc = await _stations.doc(id).get();
    if (!doc.exists) return null;
    return GasStation.fromFirestore(doc);
  }

  /// Cria um novo posto no banco de dados
  Future<String> createStation(GasStation station) async {
    final doc = await _stations.add(station.toFirestore());
    return doc.id;
  }

  /// Atualiza os preços atuais de um posto (chamado após novo registro de preço)
  Future<void> updateStationPrices({
    required String stationId,
    double? gasolineCommon,
    double? gasolinePremium,
    double? ethanol,
    double? diesel,
    bool hasPromotion = false,
  }) async {
    final updates = <String, dynamic>{
      'last_updated': Timestamp.now(),
      'has_promotion': hasPromotion,
    };

    if (gasolineCommon != null) updates['gasoline_common'] = gasolineCommon;
    if (gasolinePremium != null) updates['gasoline_premium'] = gasolinePremium;
    if (ethanol != null) updates['ethanol'] = ethanol;
    if (diesel != null) updates['diesel'] = diesel;

    await _stations.doc(stationId).update(updates);
  }

  // ═══════════════════════════════════════════════════════
  // REGISTROS DE PREÇO
  // ═══════════════════════════════════════════════════════

  /// Salva um novo registro de preço
  Future<String> savePriceRecord(PriceRecord record) async {
    final doc = await _prices.add(record.toFirestore());
    return doc.id;
  }

  /// Busca os últimos registros de preço de um posto
  Future<List<PriceRecord>> getRecentPricesForStation(
    String stationId, {
    int limit = 10,
  }) async {
    final snapshot = await _prices
        .where('station_id', isEqualTo: stationId)
        .orderBy('recorded_at', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => PriceRecord.fromFirestore(doc))
        .toList();
  }

  // ═══════════════════════════════════════════════════════
  // ARMAZENAMENTO DE FOTOS
  // ═══════════════════════════════════════════════════════

  /// Faz upload de uma foto e retorna a URL pública
  Future<String?> uploadPricePhoto({
    required File imageFile,
    required String stationId,
    required String userId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'price_photos/$stationId/${userId}_$timestamp.jpg';

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Erro ao fazer upload da foto: $e');
      return null;
    }
  }

  /// Verifica se já existe um posto naquelas coordenadas (evita duplicatas)
  Future<GasStation?> findStationNearCoordinates(
    double latitude,
    double longitude, {
    double radiusMeters = 100,
  }) async {
    const latDelta = 0.001; // ~100 metros
    const lngDelta = 0.001;

    final snapshot = await _stations
        .where('location',
            isGreaterThan: GeoPoint(latitude - latDelta, longitude - lngDelta))
        .where('location',
            isLessThan: GeoPoint(latitude + latDelta, longitude + lngDelta))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return GasStation.fromFirestore(snapshot.docs.first);
  }
}

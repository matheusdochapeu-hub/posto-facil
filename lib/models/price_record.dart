import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa um registro de preço feito por um usuário
class PriceRecord {
  final String id;
  final String stationId;       // ID do posto relacionado
  final String userId;          // ID do usuário que registrou
  final String userName;        // Nome do usuário (para exibir)

  // Preços registrados (todos opcionais — usuário registra o que viu)
  final double? gasolineCommon;   // Gasolina comum
  final double? gasolinePremium;  // Gasolina aditivada
  final double? ethanol;          // Álcool / Etanol
  final double? diesel;           // Diesel

  final bool hasPromotion;                  // Tem promoção?
  final String? promotionDescription;       // Descrição da promoção
  final String? photoUrl;                   // URL da foto enviada
  final DateTime recordedAt;                // Quando foi registrado
  final GeoPoint? recordedLocation;         // GPS de onde o usuário estava

  const PriceRecord({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.userName,
    this.gasolineCommon,
    this.gasolinePremium,
    this.ethanol,
    this.diesel,
    this.hasPromotion = false,
    this.promotionDescription,
    this.photoUrl,
    required this.recordedAt,
    this.recordedLocation,
  });

  /// Cria um PriceRecord a partir de um documento do Firestore
  factory PriceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PriceRecord(
      id: doc.id,
      stationId: data['station_id'] ?? '',
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? 'Usuário anônimo',
      gasolineCommon: (data['gasoline_common'] as num?)?.toDouble(),
      gasolinePremium: (data['gasoline_premium'] as num?)?.toDouble(),
      ethanol: (data['ethanol'] as num?)?.toDouble(),
      diesel: (data['diesel'] as num?)?.toDouble(),
      hasPromotion: data['has_promotion'] ?? false,
      promotionDescription: data['promotion_description'],
      photoUrl: data['photo_url'],
      recordedAt: (data['recorded_at'] as Timestamp).toDate(),
      recordedLocation: data['recorded_location'] as GeoPoint?,
    );
  }

  /// Converte para o formato do Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'station_id': stationId,
      'user_id': userId,
      'user_name': userName,
      if (gasolineCommon != null) 'gasoline_common': gasolineCommon,
      if (gasolinePremium != null) 'gasoline_premium': gasolinePremium,
      if (ethanol != null) 'ethanol': ethanol,
      if (diesel != null) 'diesel': diesel,
      'has_promotion': hasPromotion,
      if (promotionDescription != null)
        'promotion_description': promotionDescription,
      if (photoUrl != null) 'photo_url': photoUrl,
      'recorded_at': Timestamp.fromDate(recordedAt),
      if (recordedLocation != null) 'recorded_location': recordedLocation,
    };
  }
}

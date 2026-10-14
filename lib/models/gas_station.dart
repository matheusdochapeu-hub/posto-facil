import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa um posto de gasolina no banco de dados
class GasStation {
  final String id;
  final String name;          // Nome fantasia do posto
  final String address;       // Endereço completo
  final GeoPoint location;    // Coordenadas GPS (latitude e longitude)
  final String? phone;        // Telefone (opcional)
  final String? hours;        // Horário de funcionamento (opcional)
  final DateTime createdAt;   // Quando foi cadastrado
  final DateTime lastUpdated; // Quando foi atualizado pela última vez

  // Preços mais recentes (para exibição rápida no mapa)
  final double? gasolineCommon;   // Gasolina comum
  final double? gasolinePremium;  // Gasolina aditivada
  final double? ethanol;          // Álcool / Etanol
  final double? diesel;           // Diesel
  final bool hasPromotion;        // Tem promoção ativa?

  const GasStation({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.phone,
    this.hours,
    required this.createdAt,
    required this.lastUpdated,
    this.gasolineCommon,
    this.gasolinePremium,
    this.ethanol,
    this.diesel,
    this.hasPromotion = false,
  });

  /// Cria um GasStation a partir de um documento do Firestore
  factory GasStation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GasStation(
      id: doc.id,
      name: data['name'] ?? 'Posto sem nome',
      address: data['address'] ?? 'Endereço não informado',
      location: data['location'] as GeoPoint,
      phone: data['phone'],
      hours: data['hours'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
      gasolineCommon: (data['gasoline_common'] as num?)?.toDouble(),
      gasolinePremium: (data['gasoline_premium'] as num?)?.toDouble(),
      ethanol: (data['ethanol'] as num?)?.toDouble(),
      diesel: (data['diesel'] as num?)?.toDouble(),
      hasPromotion: data['has_promotion'] ?? false,
    );
  }

  /// Converte o GasStation para o formato do Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'location': location,
      if (phone != null) 'phone': phone,
      if (hours != null) 'hours': hours,
      'created_at': Timestamp.fromDate(createdAt),
      'last_updated': Timestamp.fromDate(lastUpdated),
      if (gasolineCommon != null) 'gasoline_common': gasolineCommon,
      if (gasolinePremium != null) 'gasoline_premium': gasolinePremium,
      if (ethanol != null) 'ethanol': ethanol,
      if (diesel != null) 'diesel': diesel,
      'has_promotion': hasPromotion,
    };
  }

  /// Retorna o preço do combustível selecionado
  double? getPriceFor(FuelType type) {
    switch (type) {
      case FuelType.gasolineCommon:
        return gasolineCommon;
      case FuelType.gasolinePremium:
        return gasolinePremium;
      case FuelType.ethanol:
        return ethanol;
      case FuelType.diesel:
        return diesel;
    }
  }

  /// Retorna latitude e longitude como valores simples
  double get latitude => location.latitude;
  double get longitude => location.longitude;
}

/// Tipos de combustível disponíveis
enum FuelType {
  gasolineCommon('Gasolina Comum', 'gasolina_comum'),
  gasolinePremium('Gasolina Aditivada', 'gasolina_aditivada'),
  ethanol('Álcool / Etanol', 'etanol'),
  diesel('Diesel', 'diesel');

  final String label;    // Nome para exibir na tela
  final String value;   // Valor interno

  const FuelType(this.label, this.value);
}

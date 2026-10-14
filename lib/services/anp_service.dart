import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gas_station.dart';

/// Representa um posto retornado diretamente pela API da ANP
class AnpStation {
  final String codigoSIMP;      // Código único do posto na ANP
  final String autorizacao;     // Número da autorização de operação
  final String razaoSocial;     // Nome oficial do posto
  final String cnpj;
  final String endereco;
  final String bairro;
  final String cep;
  final String municipio;
  final String distribuidora;   // Bandeira (Shell, Ipiranga, etc.)
  final double? latitude;
  final double? longitude;
  final List<AnpProduct> produtos; // Combustíveis disponíveis

  const AnpStation({
    required this.codigoSIMP,
    required this.autorizacao,
    required this.razaoSocial,
    required this.cnpj,
    required this.endereco,
    required this.bairro,
    required this.cep,
    required this.municipio,
    required this.distribuidora,
    this.latitude,
    this.longitude,
    required this.produtos,
  });

  factory AnpStation.fromJson(Map<String, dynamic> json) {
    // Parseia latitude e longitude (podem estar vazias)
    final latStr = json['latitude']?.toString().trim() ?? '';
    final lngStr = json['longitude']?.toString().trim() ?? '';
    final lat = latStr.isNotEmpty ? double.tryParse(latStr) : null;
    final lng = lngStr.isNotEmpty ? double.tryParse(lngStr) : null;

    // Parseia a lista de produtos/combustíveis
    final produtosJson = json['produtos'] as List<dynamic>? ?? [];
    final produtos = produtosJson
        .map((p) => AnpProduct.fromJson(p as Map<String, dynamic>))
        .toList();

    return AnpStation(
      codigoSIMP: json['codigoSIMP']?.toString() ?? '',
      autorizacao: json['autorizacao']?.toString() ?? '',
      razaoSocial: json['razaoSocial']?.toString() ?? 'Posto sem nome',
      cnpj: json['cnpj']?.toString() ?? '',
      endereco: json['endereco']?.toString() ?? '',
      bairro: json['bairro']?.toString() ?? '',
      cep: json['cep']?.toString() ?? '',
      municipio: json['municipio']?.toString() ?? '',
      distribuidora: json['distribuidora']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      produtos: produtos,
    );
  }

  /// Endereço formatado completo
  String get fullAddress {
    final parts = [endereco, bairro, municipio, 'SP']
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  /// Verifica se tem coordenadas GPS válidas
  bool get hasLocation => latitude != null && longitude != null;

  /// Verifica se vende determinado produto
  bool hasFuel(String fuelKeyword) {
    return produtos.any(
      (p) => p.produto.toUpperCase().contains(fuelKeyword.toUpperCase()),
    );
  }

  /// Converte para o modelo GasStation (para exibir no mapa)
  /// Usa coordenadas do centro de RP como fallback
  GasStation toGasStation() {
    return GasStation(
      id: codigoSIMP,
      name: _toTitleCase(razaoSocial),
      address: fullAddress,
      location: GeoPoint(
        latitude ?? -21.1767,   // Fallback: centro de Ribeirão Preto
        longitude ?? -47.8208,
      ),
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Converte string em CAIXA ALTA para Título de Capitalização Normal
  String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Não capitalizar preposições curtas
      if (['DE', 'DO', 'DA', 'E', 'EM', 'A'].contains(word)) {
        return word.toLowerCase();
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

/// Um produto/combustível de um posto da ANP
class AnpProduct {
  final String produto;    // Nome do combustível
  final int tancagem;     // Capacidade do tanque em m³
  final int qtdeBicos;    // Número de bicos (bombas)

  const AnpProduct({
    required this.produto,
    required this.tancagem,
    required this.qtdeBicos,
  });

  factory AnpProduct.fromJson(Map<String, dynamic> json) {
    return AnpProduct(
      produto: json['produto']?.toString() ?? '',
      tancagem: (json['tancagem'] as num?)?.toInt() ?? 0,
      qtdeBicos: (json['qtdeBicos'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Serviço para buscar dados cadastrais de postos na API oficial da ANP
///
/// API: https://revendedoresapi.anp.gov.br
/// Endpoint: GET /v1/combustivel?uf=SP&municipio=RIBEIRAO PRETO
///
/// IMPORTANTE: Esta API fornece dados CADASTRAIS (nome, endereço, GPS, produtos).
/// Os PREÇOS são coletados pelos usuários do app via foto/formulário.
class AnpService {
  static const String _baseUrl = 'https://revendedoresapi.anp.gov.br';
  static const String _uf = 'SP';
  static const String _municipio = 'RIBEIRAO PRETO';

  final http.Client _client;

  AnpService({http.Client? client}) : _client = client ?? http.Client();

  /// Busca todos os postos de combustível de Ribeirão Preto na API da ANP
  Future<List<AnpStation>> fetchStationsFromAnp() async {
    final uri = Uri.parse(
      '$_baseUrl/v1/combustivel?uf=$_uf&municipio=${Uri.encodeComponent(_municipio)}',
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'PostoFacilApp/1.0',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Erro na API da ANP: status ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Verifica se a resposta foi bem-sucedida
      if (json['succeeded'] != true) {
        throw Exception('API da ANP retornou erro: ${json['title']}');
      }

      final data = json['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => AnpStation.fromJson(item as Map<String, dynamic>))
          .where((station) => station.razaoSocial.isNotEmpty)
          .toList();
    } catch (e) {
      print('Erro ao buscar dados da ANP: $e');
      rethrow;
    }
  }

  /// Busca postos e filtra apenas os que têm coordenadas GPS válidas
  Future<List<AnpStation>> fetchStationsWithLocation() async {
    final all = await fetchStationsFromAnp();
    return all.where((s) => s.hasLocation).toList();
  }

  /// Sincroniza os dados da ANP com o Firestore do app
  /// Cria postos que ainda não existem no banco de dados local
  Future<SyncResult> syncWithFirestore(FirebaseFirestore db) async {
    final collection = db.collection('gas_stations');
    final stations = await fetchStationsFromAnp();

    int created = 0;
    int skipped = 0;
    int errors = 0;

    for (final station in stations) {
      try {
        // Verifica se o posto já existe pelo código SIMP da ANP
        final existing = await collection
            .where('anp_code', isEqualTo: station.codigoSIMP)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          skipped++;
          continue;
        }

        // Só cadastra postos que têm coordenadas GPS
        if (!station.hasLocation) {
          skipped++;
          continue;
        }

        // Cria o posto no Firestore
        await collection.add({
          'name': station._toTitleCase(station.razaoSocial),
          'address': station.fullAddress,
          'location': GeoPoint(station.latitude!, station.longitude!),
          'anp_code': station.codigoSIMP,
          'cnpj': station.cnpj,
          'distribuidora': station.distribuidora,
          'autorizacao': station.autorizacao,
          'created_at': Timestamp.now(),
          'last_updated': Timestamp.now(),
          'has_promotion': false,
          'source': 'ANP',
        });
        created++;
      } catch (e) {
        print('Erro ao sincronizar posto ${station.razaoSocial}: $e');
        errors++;
      }
    }

    return SyncResult(
      total: stations.length,
      created: created,
      skipped: skipped,
      errors: errors,
    );
  }
}

/// Resultado da sincronização com o Firebase
class SyncResult {
  final int total;    // Total de postos encontrados na ANP
  final int created;  // Novos postos criados no Firestore
  final int skipped;  // Postos ignorados (já existiam ou sem GPS)
  final int errors;   // Erros durante a sincronização

  const SyncResult({
    required this.total,
    required this.created,
    required this.skipped,
    required this.errors,
  });

  @override
  String toString() =>
      'SyncResult: total=$total, criados=$created, ignorados=$skipped, erros=$errors';
}

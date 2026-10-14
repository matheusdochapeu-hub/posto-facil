import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Serviço de localização — obtém a posição GPS do usuário
class LocationService {
  /// Obtém a posição atual do usuário
  /// Solicita permissão se necessário
  Future<Position?> getCurrentPosition() async {
    // Verifica se o serviço de localização está habilitado no celular
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Serviço de localização desabilitado.');
      return null;
    }

    // Verifica a permissão de localização
    LocationPermission permission = await Geolocator.checkPermission();

    // Se nunca perguntou, solicita permissão
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Permissão de localização negada.');
        return null;
      }
    }

    // Se o usuário negou permanentemente, não há como pedir novamente
    if (permission == LocationPermission.deniedForever) {
      print('Permissão de localização negada permanentemente.');
      return null;
    }

    // Obtém a posição com boa precisão
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Converte coordenadas GPS em endereço legível
  /// Ex: (-21.1767, -47.8208) → "Av. Independência, Ribeirão Preto, SP"
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return 'Endereço não encontrado';

      final place = placemarks.first;
      final parts = [
        if (place.street?.isNotEmpty == true) place.street,
        if (place.subLocality?.isNotEmpty == true) place.subLocality,
        if (place.locality?.isNotEmpty == true) place.locality,
        if (place.administrativeArea?.isNotEmpty == true)
          place.administrativeArea,
      ];

      return parts.join(', ');
    } catch (e) {
      print('Erro ao obter endereço: $e');
      return 'Endereço não disponível';
    }
  }

  /// Calcula a distância em metros entre dois pontos GPS
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Formata a distância para exibição amigável
  /// Ex: 500 → "500 m" | 1500 → "1,5 km"
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}

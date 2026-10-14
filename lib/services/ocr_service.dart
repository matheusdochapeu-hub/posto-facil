import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Resultado da leitura OCR de uma foto de tabela de preços
class OcrResult {
  final double? gasolineCommon;   // Gasolina comum encontrada
  final double? gasolinePremium;  // Gasolina aditivada encontrada
  final double? ethanol;          // Álcool encontrado
  final double? diesel;           // Diesel encontrado
  final String rawText;           // Todo o texto bruto lido na foto
  final bool hasPromotion;        // Detectou alguma promoção?

  const OcrResult({
    this.gasolineCommon,
    this.gasolinePremium,
    this.ethanol,
    this.diesel,
    required this.rawText,
    this.hasPromotion = false,
  });
}

/// Serviço de OCR — lê texto de fotos de tabelas de preços
/// Usa o ML Kit do Google (funciona offline, no próprio celular)
class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Lê o texto de uma foto e tenta extrair os preços de combustível
  Future<OcrResult> extractPricesFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    // Processa a imagem com o ML Kit
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    final rawText = recognizedText.text;
    print('Texto bruto detectado:\n$rawText');

    // Tenta extrair os preços do texto detectado
    return _parsePrices(rawText);
  }

  /// Analisa o texto bruto e extrai os preços
  OcrResult _parsePrices(String text) {
    // Normaliza o texto: tudo em minúsculas, vírgulas → pontos
    final normalized = text.toLowerCase().replaceAll(',', '.');

    // Separa em linhas para analisar linha por linha
    final lines = normalized.split('\n');

    double? gasolineCommon;
    double? gasolinePremium;
    double? ethanol;
    double? diesel;
    bool hasPromotion = false;

    for (final line in lines) {
      // Extrai o número de preço da linha (formato: X.XX ou XX.XX)
      final price = _extractPrice(line);

      // Detecta o tipo de combustível pela linha
      if (_contains(line, ['gasolina comum', 'gasolina c', 'comum'])) {
        gasolineCommon ??= price;
      } else if (_contains(line, ['aditivada', 'premium', 'podium', 'v-power', 'gasolina a'])) {
        gasolinePremium ??= price;
      } else if (_contains(line, ['alcool', 'álcool', 'etanol', 'etanol'])) {
        ethanol ??= price;
      } else if (_contains(line, ['diesel', 's10', 's500'])) {
        diesel ??= price;
      }

      // Detecta palavras relacionadas a promoção
      if (_contains(line, ['promoção', 'promocao', 'desconto', '%', 'oferta', 'especial'])) {
        hasPromotion = true;
      }
    }

    // Se não conseguiu identificar por rótulo, tenta pelo padrão de preço
    // (os preços de gasolina geralmente ficam entre R$4,00 e R$10,00)
    if (gasolineCommon == null) {
      gasolineCommon = _findPriceInRange(text, 4.0, 8.5);
    }

    return OcrResult(
      gasolineCommon: gasolineCommon,
      gasolinePremium: gasolinePremium,
      ethanol: ethanol,
      diesel: diesel,
      rawText: text,
      hasPromotion: hasPromotion,
    );
  }

  /// Verifica se a linha contém alguma das palavras-chave
  bool _contains(String line, List<String> keywords) {
    return keywords.any((keyword) => line.contains(keyword));
  }

  /// Extrai o primeiro número de preço válido de uma linha
  /// Ex: "gasolina comum 5,89" → 5.89
  double? _extractPrice(String line) {
    // Padrão: número com 1-2 dígitos antes do ponto e 2-3 dígitos depois
    final regex = RegExp(r'\b(\d{1,2})[.,](\d{2,3})\b');
    final match = regex.firstMatch(line);
    if (match == null) return null;

    final priceStr = '${match.group(1)}.${match.group(2)}';
    final price = double.tryParse(priceStr);

    // Valida se está em faixa razoável de preço de combustível (R$3 a R$12)
    if (price != null && price >= 3.0 && price <= 12.0) {
      return price;
    }
    return null;
  }

  /// Encontra o primeiro preço na faixa especificada no texto inteiro
  double? _findPriceInRange(String text, double min, double max) {
    final regex = RegExp(r'\b(\d{1,2})[.,](\d{2,3})\b');
    for (final match in regex.allMatches(text.replaceAll(',', '.'))) {
      final price = double.tryParse(match.group(0) ?? '');
      if (price != null && price >= min && price <= max) {
        return price;
      }
    }
    return null;
  }

  /// Libera os recursos do reconhecedor de texto
  void dispose() {
    _textRecognizer.close();
  }
}

import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  static Future<String> translate(
      {required String text, String from = 'en', String to = 'es'}) async {
    try {
      Translation translation =
          await _translator.translate(text, from: from, to: to);
      return translation.text;
    } catch (e) {
      debugPrint("[MI_LOG]Error en la traduccion: $e");
      return text; // Return original text on error
    }
  }
}
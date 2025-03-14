import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

class TextToSpeechService {
  static FlutterTts? _flutterTts;

  // Método para obtener o inicializar la instancia de FlutterTts
  static Future<FlutterTts> _getInstance() async {
    if (_flutterTts == null) {
      _flutterTts = FlutterTts();

      try {
        // Intentar configurar opciones básicas
        await _flutterTts!.setEngine(
            'com.google.android.tts'); // Puedes probar otros motores si quieres
        await _flutterTts!.setLanguage('en-US'); // Configura el idioma
        await _flutterTts!.setPitch(1.0); // Tono (1.0 es normal)
        await _flutterTts!.setSpeechRate(0.5); // Velocidad (0.5 es normal)
        await _flutterTts!.setVolume(1.0); // Volumen (1.0 es el máximo)
      } catch (e) {
        debugPrint('Error inicializando TTS: $e');
        // Considera mostrar un SnackBar al usuario si la inicialización falla.
      }
    }
    return _flutterTts!;
  }

  // Método para pronunciar una palabra
  static Future<void> speak(String text) async {
    try {
      final tts = await _getInstance();
      await tts.speak(text);
    } catch (e) {
      debugPrint('Error al pronunciar: $e');
      // Considera mostrar un SnackBar aquí también.  Necesitarías un BuildContext.
    }
  }

  // Detener la pronunciación
  static Future<void> stop() async {
    try {
      final tts = await _getInstance();
      await tts.stop();
    } catch (e) {
      debugPrint('Error al detener TTS: $e');
      // Considera mostrar un SnackBar.
    }
  }

  static String spelling(String word) {
    String result = '';
    String letterSeparated = '';
    List<String> words =
        word.split(' '); // Separar por espacios para palabras compuestas
    for (int i = 0; i < words.length; i++) {
      String currentWord = words[i];
      for (int j = 0; j < currentWord.length; j++) {
        String letter = currentWord[j];
        if (letter == letter.toUpperCase() && letter != letter.toLowerCase()) {
          letterSeparated += 'capital---';
        }

        letterSeparated += currentWord[j];
        if (j < currentWord.length - 1) {
          letterSeparated += '---'; // Coma entre letras
        }
      }
      if (i < words.length - 1) {
        letterSeparated +=
            '---space---'; // Doble coma entre palabras compuestas
      }
    }

    result = '$word---$letterSeparated---$word';
    return result;
  }
}

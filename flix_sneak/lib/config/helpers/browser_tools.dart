import 'package:flixsneak/infrastructure/models/category_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class BrowserTools {
  static Future<void> launchURL(String strUrl) async {
    final Uri url = Uri.parse(strUrl);

    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  static Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/datos.json');
  }

  static Future<void> escribirEnArchivo(List<CategoryModel> dtos) async {
    final file = await _getLocalFile();
    String jsonStr = jsonEncode(CategoryModel.toJsonList(dtos));
    await file.writeAsString(jsonStr);
  }

  static Future<List<CategoryModel>?> leerArchivo() async {
    try {
      final file = await _getLocalFile();
      await _crearArchivoSiNoExiste();
      String jsonStr = await file.readAsString();
      List<dynamic> jsonData = jsonDecode(jsonStr); // Convierte el JSON a lista
      return CategoryModel.fromJsonList(jsonData); // Crea una lista de MiDTO
    } catch (e) {
      print('Error al leer el archivo: $e');
      return null;
    }
  }

  static Future<void> _crearArchivoSiNoExiste() async {
    final file = await _getLocalFile();
    if (!(await file.exists())) {
      await file.writeAsString(jsonEncode([])); // Escribe una lista vacía en JSON
    }
  }
}

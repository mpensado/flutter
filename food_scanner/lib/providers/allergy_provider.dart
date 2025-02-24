import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllergyProvider with ChangeNotifier {
  List<String> _allergies = [];

  List<String> get allergies => _allergies;

  AllergyProvider() {
    _loadAllergies(); // Carga las alergias al iniciar el provider
  }

  // Cargar alergias desde SharedPreferences
  Future<void> _loadAllergies() async {
    final prefs = await SharedPreferences.getInstance();
    _allergies = prefs.getStringList('userAllergies') ?? [];
    notifyListeners(); // Notifica a los widgets que escuchan
  }

  // Añadir una alergia
  Future<void> addAllergy(String allergy) async {
    if (!_allergies.contains(allergy)) {
      _allergies.add(allergy);
      notifyListeners();
      await _saveAllergies(); // Guarda en SharedPreferences
    }
  }

  // Eliminar una alergia
  Future<void> removeAllergy(String allergy) async {
    _allergies.remove(allergy);
    notifyListeners();
    await _saveAllergies(); // Guarda en SharedPreferences
  }


  // Guardar las alergias en SharedPreferences
  Future<void> _saveAllergies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('userAllergies', _allergies);
  }
}
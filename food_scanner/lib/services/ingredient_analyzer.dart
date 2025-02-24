import 'package:food_scanner/models/ingredient.dart';
import 'package:food_scanner/models/analysis_result.dart';
import 'package:food_scanner/utils/constants.dart';
import 'package:food_scanner/providers/allergy_provider.dart'; // Importa AllergyProvider
import 'package:provider/provider.dart'; // Import provider
import 'package:flutter/material.dart'; //Para acceder al context

class IngredientAnalyzer {
  // Ahora analyze recibe el BuildContext
  Future<AnalysisResult> analyze(String ocrText, BuildContext context) async {
    String rawIngredients = _extractIngredients(ocrText);
    if (rawIngredients.isEmpty) {
      return AnalysisResult(
          extractedIngredients: [],
          prohibitedIngredients: [],
          allergens: [],
          error: "No se pudieron extraer los ingredientes.");
    }

    List<String> extractedIngredients = rawIngredients
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    // Usa el provider para obtener las alergias
    final allergyProvider = Provider.of<AllergyProvider>(context, listen: false);
    final List<String> userAllergies = allergyProvider.allergies;

    List<Ingredient> prohibited = [];
    List<Ingredient> allergens = [];

    for (final ingredientName in extractedIngredients) {
      if (PROHIBITED_INGREDIENTS.contains(ingredientName)) {
        prohibited.add(Ingredient(name: ingredientName, isProhibited: true));
      }
      if (userAllergies.contains(ingredientName)) {
        allergens.add(Ingredient(name: ingredientName));
      }
    }

    return AnalysisResult(
      extractedIngredients: extractedIngredients,
      prohibitedIngredients: prohibited,
      allergens: allergens,
    );
  }

    String _extractIngredients(String ocrText) {
      final RegExp ingredientsRegex = RegExp(r'(?<=Ingredientes:|ingredientes:|INGREDIENTES:|contiene:|Contiene:)(.*?)(?:\.|$)', caseSensitive: false, dotAll: true);
      final match = ingredientsRegex.firstMatch(ocrText);
      if (match != null) {
          return match.group(1)!.trim(); // El grupo 1 contiene los ingredientes.
      }
      return ''; //No se encontraron ingredientes
  }
}
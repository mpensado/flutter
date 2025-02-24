import 'package:food_scanner/models/ingredient.dart';

class AnalysisResult {
  final List<String> extractedIngredients;
  final List<Ingredient> prohibitedIngredients;
  final List<Ingredient> allergens;
  final String? error;

  AnalysisResult({
    required this.extractedIngredients,
    required this.prohibitedIngredients,
    required this.allergens,
    this.error,
  });
}
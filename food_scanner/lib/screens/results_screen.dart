import 'package:flutter/material.dart';
import 'package:food_scanner/models/analysis_result.dart';
import 'package:food_scanner/models/ingredient.dart';
import 'package:food_scanner/services/ingredient_analyzer.dart';
import 'package:food_scanner/widgets/ingredient_item.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Para el indicador de carga

class ResultsScreen extends StatefulWidget {
  final String recognizedText;

  ResultsScreen({required this.recognizedText});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<AnalysisResult> _analysisFuture;

  @override
  void initState() {
    super.initState();
    _analysisFuture = IngredientAnalyzer().analyze(widget.recognizedText, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados del Análisis')),
      body: FutureBuilder<AnalysisResult>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SpinKitFadingCircle(color: Colors.blue)); // Indicador de carga
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final result = snapshot.data!;
            if (result.error != null) {
              return Center(child: Text(result.error!)); // Muestra el error de análisis
            }

            return ListView(
              children: [
                if (result.prohibitedIngredients.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Ingredientes Prohibidos/Sospechosos:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                  ...result.prohibitedIngredients.map((ingredient) => IngredientItem(ingredient: ingredient, isHighlighted: true)),
                ],
                if (result.allergens.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Alérgenos:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                  ...result.allergens.map((ingredient) => IngredientItem(ingredient: ingredient, isHighlighted: true)),
                ],

                const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Todos los ingredientes:", style: TextStyle(fontWeight: FontWeight.bold)),
                ),

                ...result.extractedIngredients.map((ingredientName) {
                    //Busca en la lista de prohibidos y alergenos
                    final isProhibited = result.prohibitedIngredients.any((i) => i.name == ingredientName);
                    final isAllergen = result.allergens.any((i)=> i.name == ingredientName);

                    return IngredientItem(
                      ingredient:  Ingredient(name: ingredientName),
                      isHighlighted: isProhibited || isAllergen,
                      highlightColor: isProhibited? Colors.red : (isAllergen ? Colors.orange : null),
                      );
                }),
              ],
            );
          } else {
            return const Center(child: Text('No se encontraron resultados.'));
          }
        },
      ),
    );
  }
}
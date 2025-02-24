import 'package:flutter/material.dart';
import 'package:food_scanner/models/ingredient.dart';

class IngredientItem extends StatelessWidget {
  final Ingredient ingredient;
  final bool isHighlighted;
  final Color? highlightColor; // Color de resaltado opcional

  IngredientItem({required this.ingredient, this.isHighlighted = false, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.0),
      margin: EdgeInsets.symmetric(vertical: 2.0),
      decoration: BoxDecoration(
        color: isHighlighted ? (highlightColor ?? Colors.yellow.shade100) : null, // Usa el color proporcionado o amarillo claro
        borderRadius: BorderRadius.circular(4.0),
        border: isHighlighted? Border.all(color: highlightColor ?? Colors.yellow.shade800, width: 1.0) : null,
      ),
      child: Text(
        ingredient.name,
        style: TextStyle(
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
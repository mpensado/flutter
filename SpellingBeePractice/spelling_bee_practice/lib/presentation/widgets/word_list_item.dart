import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';

class WordListItem extends StatelessWidget {
  final Word word;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WordListItem({
    super.key,
    required this.word,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Palabra y Traducción (en la misma fila).
            Row(
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  word.translation,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),

            // Listas (debajo de la palabra/traducción).
            if (word.lists.isNotEmpty) ...[
              // Operador de propagación condicional.
              const SizedBox(height: 4), // Espacio
              Wrap(
                //  Wrap para que los chips se ajusten
                spacing: 4.0, // Espacio horizontal
                runSpacing: 4.0, // Espacio vertical
                children: word.lists
                    .map((listName) => Chip(
                          label: Text(listName),
                        ))
                    .toList(),
              ),
            ],

            //Deletreo (Opcional)
            if (word.spelling != null && word.spelling!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Deletreo: ${word.spelling}',
                style: TextStyle(fontSize: 14, color: Colors.blueGrey[700]),
              ),
            ],

            //Notas (Opcional)
            if (word.notes != null && word.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Notas: ${word.notes}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],

            // Botones de Editar y Eliminar (alineados a la derecha).
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
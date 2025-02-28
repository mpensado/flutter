import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAddToSession;

  const WordCard({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onEdit,
    required this.onAddToSession,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: BorderSide(
          width: 2.0,
          color: word.totalIncorrectCount == 0
              ? Colors.transparent
              : word.totalIncorrectCount > 0
                  ? Colors.red
                  : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                    word.word,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.start,
                  ),
                      // Mostrar el icono y el contador solo si hay errores.
                      if (word.totalIncorrectCount > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.cancel_outlined,
                            color: Colors.grey),
                        Text(
                          '${word.totalIncorrectCount}', // Mostrar el contador
                          style: TextStyle(color: Colors.grey, fontSize: 20.0),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      //color: Colors.black87,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      //color: Colors.black, // Consistent color
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            Text(
              word.translation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(word.word);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text(
                    'Escuchar',
                    //style: TextStyle(fontSize: 15.0), // Smaller font
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(word.spelling);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text(
                    'Deletrear',
                    //style: TextStyle(fontSize: 15.0), // Smaller font
                  ),
                ),
                // ElevatedButton.icon(
                //   onPressed:
                //       onAddToSession, // Use the new onAddToSession callback
                //   icon: const Icon(Icons.add), // Changed icon
                //   label: const Text(
                //     'Sesión',
                //     style: TextStyle(fontSize: 10.0),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
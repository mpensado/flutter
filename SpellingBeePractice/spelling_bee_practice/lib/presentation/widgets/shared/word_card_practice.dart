// word_card_practice.dart
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart'; // Import PracticeSession

class WordCardPractice extends StatefulWidget {
  final WordPractice word;
  final VoidCallback onDelete;
  final void Function(WordPractice word, bool isCorrect) onRecordPracticeCallback;
  final PracticeSession? selectedSession; // Make nullable
  final bool showRemoveButton;

  const WordCardPractice({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onRecordPracticeCallback,
    this.selectedSession,
    this.showRemoveButton = true,
  });

  @override
  State<WordCardPractice> createState() => WordCardPracticeState();
}

class WordCardPracticeState extends State<WordCardPractice> {

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: BorderSide(
          width: 2.0,
          color: widget.word.totalIncorrectCount == 0
              ? Colors.transparent
              : Colors.red,
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
                        widget.word.word,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.start,
                      ),
                      // if (widget.word.totalIncorrectCount > 0) ...[
                      //   const SizedBox(width: 8),
                      //   const Icon(Icons.cancel_outlined, color: Colors.grey),
                      //   Text(
                      //     '${widget.word.totalIncorrectCount}',
                      //     style:
                      //         const TextStyle(color: Colors.grey, fontSize: 20.0),
                      //   ),
                      // ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle),
                      color: Colors.green,
                      onPressed: () =>
                          widget.onRecordPracticeCallback(widget.word, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel),
                      color: Colors.red,
                      onPressed: () =>
                          widget.onRecordPracticeCallback(widget.word, false),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              widget.word.translation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(widget.word.word);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text(
                    'Escuchar',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(widget.word.spelling);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text(
                    'Deletrear',
                  ),
                ),
                if (widget.showRemoveButton)
                  ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.remove),
                    label: const Text(
                      'Quitar',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
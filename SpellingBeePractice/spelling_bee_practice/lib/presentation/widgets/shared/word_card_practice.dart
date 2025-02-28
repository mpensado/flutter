import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/domain/entities/practice_history.dart';

class WordCardPractice extends StatefulWidget {
  final Word word;
  final VoidCallback onDelete;
  final void Function(
      Word word, bool isCorrect, WordCardPracticeState cardState)
      onRecordPracticeCallback;
  final Set<int> practicedWords;
  final PracticeSession? selectedSession;
  final int resetCounter;
  final bool showRemoveButton;
  final int? errorCount; // Usado en la pestaña "Todas"

  const WordCardPractice({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onRecordPracticeCallback,
    required this.practicedWords,
    this.selectedSession,
    required this.resetCounter,
    this.showRemoveButton = true, this.errorCount,
  });

  @override
  State<WordCardPractice> createState() => WordCardPracticeState();
}

class WordCardPracticeState extends State<WordCardPractice> {
  bool isPracticed = false;
  bool? practiceResult;

  @override
  void initState() {
    super.initState();
    isPracticed = widget.practicedWords.contains(widget.word.id);

    if (isPracticed) {
      _loadLastPracticeResult();
    } else {
      practiceResult = null;
    }
  }

  @override
  void didUpdateWidget(covariant WordCardPractice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetCounter != oldWidget.resetCounter) {
      setState(() {
        isPracticed = false;
        practiceResult = null;
      });
    }
      if (widget.word.id != oldWidget.word.id) { //  Si la palabra cambió
          isPracticed = widget.practicedWords.contains(widget.word.id);
           if (isPracticed) {
             _loadLastPracticeResult();
           } else {
               practiceResult = null;
            }
      }
  }

  Future<void> _loadLastPracticeResult() async {
    final dbHelper = DBHelper();
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> history = await db.query(
        'practice_history',
        orderBy: 'practiced_at DESC',
        where: 'word_id = ? AND session_id = ?',
        whereArgs: [widget.word.id, widget.selectedSession?.id],
        limit: 1,
      );

      if (history.isNotEmpty) {
        final lastPractice = PracticeHistory.fromMap(history.first);
        setState(() {
          practiceResult = lastPractice.isCorrect;
        });
      } else {
        practiceResult = null;
      }
    } catch (e) {
      //Manejo de errores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error cargando historial: $e")));
      }
    }
  }

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
              : widget.word.totalIncorrectCount > 0
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
                    widget.word.word,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.start,
                  ),
                        if (widget.word.totalIncorrectCount > 0) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.cancel_outlined, color: Colors.grey), // Icono de error
                            Text(
                              '${widget.word.totalIncorrectCount}', // Mostrar el contador
                              style: TextStyle(color: Colors.grey, fontSize: 20.0),
                            ),
                        ],
                      ],
                    )
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.check_circle),
                        color: Colors.green,
                        onPressed: () {
                          widget.onRecordPracticeCallback(
                              widget.word, true, this);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        color: Colors.red,
                        onPressed: () {
                          widget.onRecordPracticeCallback(
                              widget.word, false, this);
                        },
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
                    //style: TextStyle(fontSize: 10.0),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    TextToSpeechService.speak(widget.word.spelling);
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text(
                    'Deletrear',
                    //style: TextStyle(fontSize: 10.0),
                  ),
                ),
                if (widget
                    .showRemoveButton) //  Mostrar solo si showRemoveButton es true
                  ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.remove),
                    label: const Text(
                      'Quitar',
                      //style: TextStyle(fontSize: 10.0),
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
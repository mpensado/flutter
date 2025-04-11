import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card_practice.dart';

class RandomPracticeView extends StatefulWidget {
  final List<WordPractice> words;
  final String filter;
  const RandomPracticeView(
      {super.key, required this.words, required this.filter});

  @override
  State<RandomPracticeView> createState() => _RandomPracticeViewState();
}

class _RandomPracticeViewState extends State<RandomPracticeView> {
  WordPractice? currentWord;
  bool hasRepeated = false;
  bool isLoading = false;
  List<int> lastPracticedWords = [];
  int totalCorrectCount = 0;
  int totalAttemptsCount = 0;
  int totalIncorrectCount = 0;
  int currentWordIncorrectCount = 0;
  bool gameStarted = false;
  bool practiceEnded = false;
  List<Map<String, dynamic>> practiceSummary = [];
  List<Map<String, dynamic>> practicePartialSummary = [];
  List<Map<String, dynamic>> wordsAttempts = [];
  List<Map<String, dynamic>> wordsCorrect = [];
  List<Map<String, dynamic>> wordsIncorrect = [];

  String practiceMessage = "";
  List<String> practiceIncorrectWords = [];
  List<String> practiceCorrectWords = [];

    void _startNewPractice() {
    setState(() {
      currentWord = null;
      hasRepeated = false;
      isLoading = false;
      totalCorrectCount = 0;
      totalIncorrectCount = 0;
      currentWordIncorrectCount = 0;
      gameStarted = false;
      practiceEnded = false;
      practiceSummary.clear();
      practicePartialSummary.clear();
      lastPracticedWords = [];
    });
  }

  Future<void> _loadNextWord() async {
    setState(() {
      isLoading = true;
      hasRepeated = false;
    });

    try {
      List<WordPractice> availableWords = widget.words.where((word) {
        return !practicePartialSummary
            .any((summary) => summary['word'] == word.word);
      }).toList();

      if (availableWords.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          availableWords = widget.words;
          totalAttemptsCount = availableWords.length;
          practicePartialSummary.clear();
        }
      }

      final nextWord = await WordRepository.getWordsForRandomPractice(
          words: availableWords, filter: widget.filter);
      if (mounted) {
        setState(() {
          currentWord = nextWord;
          isLoading = false;
          if (currentWord != null) {
            TextToSpeechService.speak(currentWord!.word);
            currentWordIncorrectCount = currentWord!.totalIncorrectCount;
            if (practiceSummary.firstWhereOrNull(
                    (element) => element['word'] == currentWord!.word) ==
                null) {
              practiceSummary.add({
                'word': currentWord!.word,
                'attempts': 0,
                'errors': 0,
              });
              practicePartialSummary.add({
                'word': currentWord!.word,
                'attempts': 0,
                'errors': 0,
              });
            }
            // practiceSummary.firstWhereOrNull((element) => element['word'] == currentWord!.word)!['attempts']++;

            if (!lastPracticedWords.contains(currentWord!.id)) {
              lastPracticedWords.insert(0, currentWord!.id!);
              if (lastPracticedWords.length > 3) {
                lastPracticedWords.removeLast();
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text("Error al cargar la palabra: $e")),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _recordPracticeResult(bool isCorrect, Word word, String listName) async {
    if (currentWord == null) return;

    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      await db.insert('practice_history', {
        'word_id': word.id,
        'session_id': -1,
        'practiced_at': DateTime.now().toIso8601String(),
        'session_type': 'random',
      });
      practiceSummary.firstWhereOrNull(
          (element) => element['word'] == currentWord!.word)!['attempts']++;

      await WordRepository.updateWordCounters(currentWord!.id!, isCorrect,widget.filter, 'random');

      setState(() {
        if (isCorrect) {
          totalCorrectCount++;
        } else {
          totalIncorrectCount++;
          currentWordIncorrectCount++;
          final wordSummary = practiceSummary.firstWhereOrNull(
              (element) => element['word'] == currentWord!.word);
          if (wordSummary != null) {
            wordSummary['errors']++;
          }
        }
      });

      _loadNextWord();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al guardar el resultado: $e")));
      }
    }
  }

  // En _RandomPracticeViewState:

  Future<void> _endPractice() async {
    final db = DBHelper();
    final database = await db.database;
    double average;
    String messageL1 = "";
    String messageL2 = "";
    List<Map<String, dynamic>> incorrectWords = [];
    List<Map<String, dynamic>> correctWords = [];
    List<Map<String, dynamic>> attemptsWords = [];
    List<Map<String, dynamic>> practiceHistory = [];

    //---------------------------------
    if (widget.words.isNotEmpty) {
      if (widget.filter != 'Todo') {
        practiceHistory = await database.rawQuery('''
        SELECT
            w.*,
            ph.practiced_at,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
        FROM
            words w
        LEFT JOIN
            practice_history ph ON ph.word_id = w.id AND ph.session_type = 'random'
        JOIN
            word_lists wl ON w.id = wl.word_id
        WHERE
            wl.list_name = ?
        GROUP BY
            w.id
        ORDER BY
            ph.practiced_at DESC;
      ''', [widget.filter]);
      } else {
        practiceHistory = await database.rawQuery('''
        SELECT
            w.*,
            ph.practiced_at,
            ph.correct_count,
            ph.incorrect_count,
            ph.total_incorrect_count
        FROM
            words w
        LEFT JOIN
            practice_history ph ON ph.word_id = w.id AND ph.session_type = 'random'
        JOIN
            word_lists wl ON w.id = wl.word_id
        GROUP BY
            w.id
        ORDER BY
            ph.practiced_at DESC;
      ''');
      }
    } else {
      practiceHistory = [];
    }
    //-----------------------------------

    attemptsWords = practiceHistory
        .where((summary) => (summary['practiced_at']) != null)
        .toList();

    if (attemptsWords.isNotEmpty) {
      if (practiceHistory.isNotEmpty) {
        average = (attemptsWords
                    .where((summary) => (summary['correct_count'] as int) >= 0)
                    .length /
                attemptsWords.length) *
            100;
      } else {
        average = 0;
      }

      if (average == 100) {
        messageL1 = "¡Excelente!";
        messageL2 = "Todas tus palabras fueron correctas.";
      } else if (average >= 80) {
        messageL1 = "¡Felicidades!";
        messageL2 = "Casi todas tus palabras fueron correctas.";
      } else if (average >= 51) {
        messageL1 = "¡Bien!";
        messageL2 = "Algunas palabras necesitan un repaso.";
      } else if (average >= 31) {
        messageL1 = "¡A practicar!";
        messageL2 = "Hay varias palabras por mejorar.";
      } else {
        messageL1 = "¡Necesitas más práctica!";
        messageL2 = "No te desanimes.";
      }

      incorrectWords = practiceHistory
          .where((summary) =>
              (summary['incorrect_count']) != null &&
              (summary['incorrect_count']) > 0)
          .toList();

      correctWords = practiceHistory
          .where((summary) =>
              (summary['incorrect_count']) != null &&
              (summary['incorrect_count']) == 0 &&
              (summary['correct_count']) != null &&
              (summary['correct_count']) > 0)
          .toList();
    } else {
      messageL1 = "";
      messageL2 = "";
    }

    setState(() {
      practiceEnded = true;
      practiceMessage = "$messageL1 $messageL2";
      practiceIncorrectWords =
          incorrectWords.map((map) => map['word'].toString()).toList();
      practiceCorrectWords =
          correctWords.map((map) => map['word'].toString()).toList();
      this.messageL1 = messageL1;
      this.messageL2 = messageL2;
    });
  }

  String messageL1 = "";
  String messageL2 = "";

  @override
  Widget build(BuildContext context) {
    if (!gameStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text("Práctica Aleatoria")),
        body: Center(
          child: ElevatedButton(
            child: const Text("Comenzar Práctica"),
            onPressed: () {
              setState(() {
                gameStarted = true;
              });
              _loadNextWord();
            },
          ),
        ),
      );
    }
    if (practiceEnded) {
      final screenWidth =
          MediaQuery.of(context).size.width; // Obtener ancho de la pantalla
      return Scaffold(
        appBar: AppBar(
          title: const Text("Práctica Aleatoria - Resumen"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    // Envuelve los Text en un widget Center
                    child: Text(
                      messageL1,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    // Envuelve los Text en un widget Center
                    child: Text(
                      messageL2,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Aciertos",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text("$totalCorrectCount"),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Errores",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text("$totalIncorrectCount"),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Palabras",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text("$totalAttemptsCount"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (practiceIncorrectWords.isNotEmpty) ...[
                    const Text(
                      "Palabras por practicar:",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      // Usar SizedBox para establecer el ancho fijo
                      width: screenWidth,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: practiceIncorrectWords.map((word) {
                              return Chip(
                                label: Text(word),
                                backgroundColor: Colors.red[100],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (practiceCorrectWords.isNotEmpty) ...[
                    const Text(
                      "Palabras correctas:",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      // Usar SizedBox para establecer el ancho fijo
                      width: screenWidth,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: practiceCorrectWords.map((word) {
                              return Chip(
                                label: Text(word),
                                backgroundColor: Colors.green[100],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Center(
                    child: ElevatedButton(
                      onPressed: _startNewPractice,
                      child: const Text("Nueva Práctica"),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Práctica Aleatoria'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      'Filtro Aplicado: ${widget.filter}',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Palabras en la lista: ${widget.words.length}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (isLoading) ...[
                const CircularProgressIndicator(),
              ] else if (currentWord != null) ...[
                Text(
                    "Aciertos: $totalCorrectCount | Errores: $totalIncorrectCount"),
                const SizedBox(height: 8),
                Center(
                  child: WordCardPractice(
                    key: ValueKey(currentWord!.id),
                    word: currentWord!,
                    onDelete: () {},
                    onRecordPracticeCallback: (word, isCorrect) {
                      _recordPracticeResult(isCorrect, word, widget.filter);
                    },
                    selectedSession: null,
                    showRemoveButton: false,
                  ),
                ),
              ] else ...[
                const Text("No hay palabras disponibles."),
              ]
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _endPractice,
            tooltip: 'Terminar Práctica',
            child: const Icon(Icons.stop),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _startNewPractice,
            tooltip: 'Reiniciar Práctica',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

}

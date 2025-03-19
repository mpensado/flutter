import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/helpers/db_helper.dart';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';
import 'package:path/path.dart';
import 'dart:async'; // Importante para Timer (debounce)
import 'package:collection/collection.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card_practice.dart';

class RandomPracticeView extends StatefulWidget {
  final List<Word> words;
  final String filter;
  const RandomPracticeView(
      {super.key, required this.words, required this.filter});

  @override
  State<RandomPracticeView> createState() => _RandomPracticeViewState();
}

class _RandomPracticeViewState extends State<RandomPracticeView> {
  Word? currentWord;
  bool hasRepeated = false;
  bool isLoading = false; // Para mostrar un indicador de carga
  List<int> lastPracticedWords = []; //Para controlar el espaciado.
  final AudioPlayer _audioPlayer = AudioPlayer();
  int totalCorrectCount = 0; // Aciertos totales en la sesión
  int totalIncorrectCount = 0; // Errores totales en la sesión
  int currentWordIncorrectCount = 0; //Errores para la palabra actual.
  bool gameStarted = false; // Para el botón de inicio
  bool practiceEnded = false; // Para mostrar el resumen final
  List<Map<String, dynamic>> practiceSummary = []; // Lista para el resumen

  // Se agregan estas nuevas variables para manejar la data del mensaje final.
  String practiceMessage = "";
  List<String> practiceIncorrectWords = [];
  List<String> practiceCorrectWords = [];

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void _startNewPractice() {
    setState(() {
      currentWord = null;
      hasRepeated = false;
      isLoading = false;
      totalCorrectCount = 0;
      totalIncorrectCount = 0;
      currentWordIncorrectCount = 0;
      gameStarted = false; // Resetear
      practiceEnded = false; // Resetear
      practiceSummary.clear(); // Limpiar el resumen
      lastPracticedWords = [];
    });
  }

  Future<void> _loadNextWord() async {
    setState(() {
      isLoading = true;
      hasRepeated = false;
      // currentWordIncorrectCount = 0; // NO REINICIAR AQUÍ
    });

    try {
      final nextWord =
          await WordRepository.getWordsForRandomPractice(words: widget.words);
      if (mounted) {
        setState(() {
          currentWord = nextWord;
          isLoading = false;
          if (currentWord != null) {
            TextToSpeechService.speak(currentWord!.word);
            currentWordIncorrectCount =
                currentWord!.totalIncorrectCount; //  CARGAR ERRORES
            if (practiceSummary.firstWhereOrNull(
                    (element) => element['word'] == currentWord!.word) ==
                null) {
              practiceSummary.add({
                'word': currentWord!.word,
                'attempts': 0,
                'errors': 0,
              });
            }
            practiceSummary.firstWhereOrNull((element) =>
                element['word'] == currentWord!.word)!['attempts']++;

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

  Future<void> _recordPracticeResult(bool isCorrect, Word word) async {
    // Add Word parameter
    if (currentWord == null) return;

    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      // Usar la nueva columna session_type.  NO usamos sessionID en la práctica aleatoria.
      await db.insert('practice_history', {
        'word_id': word.id, // Use the passed word
        'session_id':
            -1, // Usar un valor centinela (-1) o NULL para indicar que no hay sesión.
        'is_correct': isCorrect ? 1 : 0,
        'practiced_at': DateTime.now().toIso8601String(),
        'session_type': 'random', //  Valor para la práctica aleatoria.
      });

      await WordRepository.updateWordCounters(currentWord!.id!, isCorrect);

      // // Actualizar la base de datos
      // await db.update(
      //   DBHelper().tableWords,
      //   {
      //     'correct_count': currentWord!.correctCount,
      //     'total_incorrect_count': currentWord!.totalIncorrectCount,
      //   },
      //   where: 'id = ?',
      //   whereArgs: [currentWord!.id],
      // );

      setState(() {
        if (isCorrect) {
          totalCorrectCount++;
        } else {
          totalIncorrectCount++;
          currentWordIncorrectCount++;
          // Actualizar errores en el resumen
          final wordSummary = practiceSummary.firstWhereOrNull(
              (element) => element['word'] == currentWord!.word);
          if (wordSummary != null) {
            wordSummary['errors']++;
          }
        }
      });

      _loadNextWord(); // Cargar la siguiente palabra
    } catch (e) {
      if (mounted) {
        //Siempre comprobar.
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(content: Text("Error al guardar el resultado: $e")));
      }
    }
  }

  void _endPractice() {
    double average;
    String message;
    List<String> incorrectWords = [];
    List<String> correctWords = [];

    // Calcular promedio
    if (practiceSummary.isNotEmpty) {
      average = (totalCorrectCount / practiceSummary.length) * 100;
    } else {
      average = 0;
    }

    // Determinar mensaje
    if (average == 100) {
      message = "¡Excelente! Todas tus palabras fueron correctas.";
    } else if (average >= 80) {
      message = "¡Felicidades! Casi todas tus palabras fueron correctas.";
    } else if (average >= 51) {
      message = "¡Bien! Algunas palabras necesitan un repaso.";
    } else if (average >= 31) {
      message = "¡A practicar! Hay varias palabras por mejorar.";
    } else {
      message = "¡Necesitas más práctica! No te desanimes.";
    }

    // Separar palabras correctas e incorrectas
    for (var summary in practiceSummary) {
      if (summary['errors'] > 0) {
        incorrectWords.add(summary['word']);
      } else {
        correctWords.add(summary['word']);
      }
    }

    setState(() {
      practiceEnded = true; // Mostrar resumen
      practiceMessage = message;
      practiceIncorrectWords = incorrectWords;
      practiceCorrectWords = correctWords;
    });
  }

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
              _loadNextWord(); // Iniciar carga de palabras
            },
          ),
        ),
      );
    }

    if (practiceEnded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Práctica Aleatoria - Resumen"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              //Agregado para permitir scroll en caso de mucho texto.
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    practiceMessage,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (practiceIncorrectWords.isNotEmpty) ...[
                    const Text(
                      "Palabras por practicar:",
                      textAlign:TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: practiceIncorrectWords
                          .map((word) => Text("- $word"))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (practiceCorrectWords.isNotEmpty) ...[
                    const Text(
                      "Palabras correctas:",
                      textAlign:TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: practiceCorrectWords
                          .map((word) => Text("- $word"))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    "Aciertos: $totalCorrectCount | Errores: $totalIncorrectCount | Practicadas: ${practiceSummary.length}",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _startNewPractice,
                    child: const Text("Nueva Práctica"),
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
                child: Container(
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
              ),
              if (isLoading) ...[
                const CircularProgressIndicator(),
              ] else if (currentWord != null) ...[
                Text(
                    "Aciertos: $totalCorrectCount | Errores: $totalIncorrectCount"),
                const SizedBox(height: 8),
                Center(
                  //Centra el Card
                  child: WordCardPractice(
                    key: ValueKey(currentWord!.id),
                    word: currentWord!,
                    onDelete: () {},
                    onRecordPracticeCallback: (word, isCorrect) {
                      _recordPracticeResult(isCorrect, word);
                    },
                    //practicedWords: {},
                    selectedSession: null,
                    //resetCounter: 0,
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
        //Dos botones flotantes
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

  @override
  void dispose() {
    _audioPlayer.dispose(); // Liberar recursos
    super.dispose();
  }
}
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
  const RandomPracticeView({super.key});

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
      final nextWord = await WordRepository.getWordsForRandomPractice();
      if (mounted) {
        setState(() {
          currentWord = nextWord;
          isLoading = false;
          if (currentWord != null) {
            TextToSpeechService.speak(currentWord!.word);
            currentWordIncorrectCount =
                currentWord!.totalIncorrectCount; //  CARGAR ERRORES
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

  Future<void> _recordPracticeResult(bool isCorrect) async {
    if (currentWord == null) return;

    try {
      final dbHelper = DBHelper();
      final db = await dbHelper.database;
      // Usar la nueva columna session_type.  NO usamos sessionID en la práctica aleatoria.
      await db.insert('practice_history', {
        'word_id': currentWord!.id,
        'session_id':
            -1, // Usar un valor centinela (-1) o NULL para indicar que no hay sesión.
        'is_correct': isCorrect ? 1 : 0,
        'practiced_at': DateTime.now().toIso8601String(),
        'session_type': 'random', //  Valor para la práctica aleatoria.
      });

      await WordRepository.updateWordCounters(currentWord!.id!, isCorrect);

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
    setState(() {
      practiceEnded = true; // Mostrar resumen
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Resumen de la Práctica:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: practiceSummary.length,
                  itemBuilder: (context, index) {
                    final sortedSummary = List<Map<String, dynamic>>.from(
                        practiceSummary); // Copia para no modificar el original.
                    sortedSummary.sort((a, b) => a['attempts'].compareTo(
                        b['attempts'])); // Ordenar ASCENDENTE por intentos.

                    final wordData =
                        sortedSummary[index]; // Usa la lista ordenada.
                    return ListTile(
                      title: Text(wordData['word']),
                      subtitle: Text(
                          "Intentos: ${wordData['attempts']}, Errores: ${wordData['errors']}"),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _startNewPractice,
                child: const Text("Nueva Práctica"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Práctica Aleatoria'),
      ),
      body: SingleChildScrollView(
        // <-- Añade SingleChildScrollView
        child: Center(
          // <-- Centra la columna
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centra verticalmente
            children: [
              if (isLoading) ...[
                const CircularProgressIndicator(),
              ] else if (currentWord != null) ...[
                Text(
                    "Aciertos: $totalCorrectCount | Errores: $totalIncorrectCount | Errores en palabra: $currentWordIncorrectCount"),
                const SizedBox(height: 8),
                Center(
                  //Centra el Card
                  child: WordCardPractice(
                    key: ValueKey(currentWord!.id),
                    word: currentWord!,
                    onDelete: () {},
                    onRecordPracticeCallback: (word, isCorrect, cardState) {
                      _recordPracticeResult(isCorrect);
                    },
                    practicedWords: {},
                    selectedSession: null,
                    resetCounter: 0,
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

import 'package:flutter/material.dart';
import 'package:spelling_bee_practice/domain/entities/round.dart';
import 'dart:math';
import 'package:spelling_bee_practice/infrastructure/repositories/word_repository.dart'; // Asegúrate de que los imports son correctos
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/presentation/utils/text_to_speech_service.dart';

class SpellingBeeView extends StatefulWidget {
  const SpellingBeeView({super.key});

  @override
  State<SpellingBeeView> createState() => _SpellingBeeViewState();
}

class _SpellingBeeViewState extends State<SpellingBeeView> {
  int currentRound = 1;
  List<Word> wordsForCurrentRound = [];
  int currentWordIndexInRound = 0;
  bool hasRepeated = false;
  Word? currentWord;
  bool gameOver = false;
  String? errorMessage;
  int roundCorrectCount = 0;
  int roundIncorrectCount = 0;
  bool gameStarted = false;
  bool roundCompleted = false;
  bool isSuddenDeath = false; // Indica si estamos en muerte súbita
  bool playerTurn = true; // Controla el turno (true: speller, false: oponente)
  String? winner;
  bool? isCorrect = true;

  List<Round> rounds = [
    Round(roundNumber: 1, numberOfWords: 3, canRepeat: true, canPause: true),
    Round(roundNumber: 2, numberOfWords: 3, canRepeat: true, canPause: false),
    Round(roundNumber: 3, numberOfWords: 2, canRepeat: false, canPause: false),
    Round(roundNumber: 4, numberOfWords: 1, canRepeat: false, canPause: false),
    Round(
        roundNumber: 5,
        numberOfWords: 5,
        canRepeat: false,
        canPause: false), // AHORA 5 Vocabulario
  ];

  Map<int, Map<String, int>> roundResults = {};

  void startNewSpellingBeeSession() {
    setState(() {
      currentRound = 1;
      wordsForCurrentRound = [];
      currentWordIndexInRound = 0;
      hasRepeated = false;
      currentWord = null;
      gameOver = false;
      errorMessage = null;
      roundCorrectCount = 0;
      roundIncorrectCount = 0;
      gameStarted = false;
      roundCompleted = false;
      roundResults.clear();
      isSuddenDeath = false; // Reiniciar la muerte súbita
      playerTurn = true; // Siempre empieza el speller
    });
  }

  void nextRound() {
    roundResults[currentRound] = {
      'correct': roundCorrectCount,
      'incorrect': roundIncorrectCount,
    };

    if (currentRound < rounds.length) {
      setState(() {
        currentRound++;
        currentWordIndexInRound = 0;
        hasRepeated = false;
        roundCorrectCount = 0;
        roundIncorrectCount = 0;
        roundCompleted = false;
        generateWordsForRound(currentRound);
      });
    } else {
      //Entrar a muerte súbita
      setState(() {
        isSuddenDeath = true;
        currentWordIndexInRound = 0;
        hasRepeated = false;
        roundCorrectCount = 0;
        roundIncorrectCount = 0;
        roundCompleted = false; // Reiniciar para la nueva palabra
        generateWordsForRound(currentRound + 1);
      });
    }
  }

  Future<void> generateWordsForRound(int roundNumber) async {
    int numWords;
    if (roundNumber <= rounds.length) {
      numWords = rounds[roundNumber - 1].numberOfWords;
    } else {
      numWords = 1; // Muerte súbita: 1 palabra por turno
    }

    final random = Random();
    try {
      final allWords = await WordRepository.getAllWords();
      if (allWords.isNotEmpty) {
        allWords.shuffle(random);
        setState(() {
          wordsForCurrentRound = allWords.take(numWords).toList();
          loadCurrentWord();
        });
      } else {
        setState(() {
          wordsForCurrentRound = [];
          currentWord = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al generar Vocabulario: $e")),
        );
      }
      setState(() {
        wordsForCurrentRound = [];
        currentWord = null;
      });
    }
  }

  void loadCurrentWord() {
    if (wordsForCurrentRound.isNotEmpty &&
        currentWordIndexInRound < wordsForCurrentRound.length) {
      setState(() {
        currentWord = wordsForCurrentRound[currentWordIndexInRound];
        hasRepeated = false;
        TextToSpeechService.speak(currentWord!.word);
      });
    } else {
      if (!isSuddenDeath) {
        //Si no estamos en muerte súbita, pasamos de ronda.
        nextRound();
      } //Si estamos en muerte súbita, _recordSpellingBeeResult se encarga de la lógica
    }
  }

  void handleRepeat() {
    if (rounds[min(currentRound - 1, rounds.length - 1)].canRepeat &&
        !hasRepeated) {
      setState(() {
        hasRepeated = true;
      });
      TextToSpeechService.speak(currentWord!.word);
    }
  }

  // Simula el resultado del oponente virtual.
  bool simulateOpponent() {
    final random = Random();
    return random.nextInt(2) == 0; // 0 = acierto (true), 1 = fallo (false)
  }

  void recordSpellingBeeResult(bool isCorrect) {
    if (currentWord == null) return;

    Round currentRoundRules = rounds[min(currentRound - 1, rounds.length - 1)];

    setState(() {
      //Logica de rondas normales
      if (!isSuddenDeath) {
        if (!isCorrect) {
          roundIncorrectCount++;
          if (!currentRoundRules.canRepeat) {
            //Si respondio incorrectamente
            roundResults[currentRound] = {
              'correct': roundCorrectCount,
              'incorrect': roundIncorrectCount,
            };
            gameOver = true;
            errorMessage = "Error en la Ronda $currentRound";
            return;
          }
        } else {
          roundCorrectCount++;
        }

        currentWordIndexInRound++;
        if (currentWordIndexInRound < wordsForCurrentRound.length) {
          //Si aun hay Vocabulario
          loadCurrentWord();
        } else {
          //Si ya no hay Vocabulario
          roundCompleted = true; // Fin de la ronda
          roundResults[currentRound] = {
            'correct': roundCorrectCount,
            'incorrect': roundIncorrectCount,
          };

        }
      } else {
        //Logica de muerte súbita
        //MUERTE SÚBITA
        if (playerTurn) {
          // Turno del speller
          if (isCorrect) {
            playerTurn = false; // Turno del oponente
            roundCorrectCount++; //Aumentar aciertos en la ronda.
            roundCompleted = true; //Mostrar mensaje.
          } else {
            // El speller falló, ahora a ver que pasa con el oponente
            roundIncorrectCount++; //Aumentar fallos de la ronda
            if (simulateOpponent()) {
              //Si el oponente virtual acierta.
              //El oponente virtual acertó, speller pierde
              gameOver = true;
              errorMessage = "Has perdido en la muerte súbita.";
            } else {
              //Si el oponente falla, darle otra palabra al speller
              roundCompleted = true;
              playerTurn = true;
            }
          }
        } else {
          // Turno del oponente (simulado)
          if (simulateOpponent()) {
            // Oponente acertó, generar nueva palabra para el speller
            playerTurn = true; // Regresa el turno al speller
            roundCompleted = true;
          } else {
            // Oponente falló, el speller gana
            gameOver = true;
            winner = "¡Felicidades, has ganado!"; // Define winner
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (gameOver) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Spelling Bee"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: startNewSpellingBeeSession,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                //Si winner es null, mostramos el mensaje de error, si no, mostramos el de ganador
                winner ?? errorMessage ?? "¡Completaste todas las rondas!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text("Resultados por Ronda:",
                  style: Theme.of(context).textTheme.titleLarge),
              for (var round = 1; round <= roundResults.length; round++) ...[
                //Uso de la expansión de colecciones
                Text(
                    "Ronda $round: Aciertos: ${roundResults[round]!['correct']}, Errores: ${roundResults[round]!['incorrect']}",
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: startNewSpellingBeeSession,
                child: const Text("Jugar de Nuevo"),
              ),
            ],
          ),
        ),
      );
    }

    if (!gameStarted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Spelling Bee"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: startNewSpellingBeeSession,
            ),
          ],
        ),
        body: Center(
          child: ElevatedButton(
            child: const Text("Iniciar Spelling Bee"),
            onPressed: () {
              setState(() {
                gameStarted = true;
                generateWordsForRound(currentRound);
              });
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpellingBee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: startNewSpellingBeeSession,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Ronda $currentRound${isSuddenDeath ? ' (Muerte Súbita)' : ''}",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            if (currentWord != null && !roundCompleted)
              Text(
                "Palabra ${currentWordIndexInRound + 1} de ${wordsForCurrentRound.length}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 20),
            if (roundCompleted) ...[
              // Mensajes de final de ronda
              if (!isSuddenDeath &&
                  roundCorrectCount == wordsForCurrentRound.length) ...[
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const Text("¡Felicidades! Pasaste a la siguiente ronda.",
                    textAlign: TextAlign.center),
              ] else if (!isSuddenDeath) ...[
                const Icon(Icons.cancel, size: 100, color: Colors.red),
                Text("Lo siento, no pasaste la ronda $currentRound",
                    textAlign: TextAlign.center),
              ] else if (isSuddenDeath) ...[
                //Mensajes para la muerte súbita.
                if (!playerTurn && isCorrect!) ...[
                  //Si acierta el speller, turno del oponente
                  const Icon(Icons.check_circle,
                      size: 100, color: Colors.green),
                  const Text("Turno del contrincante.",
                      textAlign: TextAlign.center),
                ] else if (!playerTurn && !isCorrect!) ...[
                  const Icon(Icons.cancel, size: 100, color: Colors.red),
                  const Text("¡Felicidades!.", textAlign: TextAlign.center),
                ] else if (playerTurn && isCorrect!) ...[
                  const Icon(Icons.check_circle,
                      size: 100, color: Colors.green),
                  const Text("Contrincante ha acertado. Tu turno",
                      textAlign: TextAlign.center),
                ] else ...[
                  //Falla el speller, turno del oponente a ver que pasa.
                  const Icon(Icons.cancel, size: 100, color: Colors.red),
                  Text("Turno del contrincante", textAlign: TextAlign.center),
                ]
              ],

              const SizedBox(height: 20),
              if (!gameOver &&
                      (!isSuddenDeath &&
                          roundCorrectCount == wordsForCurrentRound.length) ||
                  (isSuddenDeath)) // Mostrar solo si no es Game Over y pasó la ronda.
                ElevatedButton(
                  onPressed: () {
                    if (isSuddenDeath) {
                      if (playerTurn) {
                        generateWordsForRound(currentRound + 1);
                        setState(() {
                          //Resetear variables
                          roundCompleted = false;
                        });
                      } else {
                        //Si le toca al oponente, simular
                        if (simulateOpponent()) {
                          setState(() {
                            roundCompleted = false;
                            playerTurn = true;
                          });
                          generateWordsForRound(currentRound +
                              1); //Generar nueva palabra para el speller
                        } else {
                          //El oponente ha fallado, el speller gana.
                          setState(() {
                            gameOver = true;
                            winner = "¡Felicidades, has ganado!";
                          });
                        }
                      }
                    } else if (!isSuddenDeath &&
                        roundCorrectCount == wordsForCurrentRound.length) {
                      //Si pasamos la ronda, y no estamos en muerte súbita, siguiente ronda.
                      nextRound();
                    }
                  },
                  child: Text(isSuddenDeath
                      ? "Siguiente Palabra"
                      : "Iniciar Siguiente Ronda"), //Texto del botón
                ),
            ],
            if (currentWord != null && !roundCompleted) ...[
              Text(currentWord!.word,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: rounds[min(currentRound - 1, rounds.length - 1)]
                            .canRepeat &&
                        !hasRepeated
                    ? handleRepeat
                    : null,
                child:
                    Text(hasRepeated ? "Repetición usada" : "Repetir Palabra"),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text("Correcto"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      recordSpellingBeeResult(true);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text("Incorrecto"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      recordSpellingBeeResult(false);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Aciertos: $roundCorrectCount - Errores: $roundIncorrectCount",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else if (!roundCompleted)
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

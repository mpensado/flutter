import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';

class WordPractice extends Word{
  final int correctCount;     // Contador de aciertos
  final int incorrectCount;   // Contador de errores (para espaciado)
  final int totalIncorrectCount; 

  WordPractice({
    required super.word,
    required super.translation,
    required super.spelling,
    required super.createdAt,
    super.lists,
    required this.correctCount,
    required this.incorrectCount, 
    required this.totalIncorrectCount,
  });

  factory WordPractice.fromWordAndPracticeHistory(
    Word word,
    String listName,
    PracticeHistory? practiceHistory,
  ) {
    return WordPractice(
      word: word.word,
      translation: word.translation,
      spelling: word.spelling,
      createdAt: word.createdAt,
      correctCount: practiceHistory!.correctCount,
      incorrectCount: practiceHistory.incorrectCount,
      totalIncorrectCount: practiceHistory.totalIncorrectCount,
      lists: word.lists
      
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'lists': lists,
      'createdAt': createdAt.toIso8601String(),
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'total_incorrect_count': totalIncorrectCount,
    };
  }

  factory WordPractice.fromMap(Map<String, dynamic> map, {List<String>? lists}) {
    return WordPractice(
      word: map['word'],
      lists: lists ?? [],
      createdAt: map['created_at'] is String
        ? DateTime.parse(map['created_at'])
        : map['created_at'], //  <--  Comprueba el tipo
      correctCount: map['correct_count'] ?? 0,
      incorrectCount: map['incorrect_count'] ?? 0,
      totalIncorrectCount: map['total_incorrect_count'] ?? 0, 
      translation: map['translation'], 
      spelling: map['spelling'],
    );
  }
}
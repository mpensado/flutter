import 'package:spelling_bee_practice/domain/entities/practice_history.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';

class WordPractice extends Word{
  final int correctCount;     // Contador de aciertos
  final int incorrectCount;   // Contador de errores (para espaciado)
  final int totalIncorrectCount; 
  final String listName;      // Nombre de la lista (si es necesario)

  WordPractice({
    super.id,
    required super.word,
    required super.translation,
    super.pronunciation,
    required super.spelling,
    super.categoryId,
    super.notes,
    required super.createdAt,
    super.lastPractice,
    super.lists = const [], // Lista vacía por defecto
    required this.correctCount,
    required this.incorrectCount, 
    required this.totalIncorrectCount,
    required this.listName, // Nombre de la lista por defecto
  });

  factory WordPractice.fromWordAndPracticeHistory(
    Word word,
    String listName,
    PracticeHistory? practiceHistory,
  ) {
    return WordPractice(
      id: word.id,
      word: word.word,
      translation: word.translation,
      pronunciation: word.pronunciation,
      spelling: word.spelling,
      categoryId: word.categoryId,
      notes: word.notes,      
      createdAt: word.createdAt,
      lastPractice: word.lastPractice,
      lists: word.lists.isNotEmpty ? word.lists : [listName],
      correctCount: practiceHistory!.correctCount,
      incorrectCount: practiceHistory.incorrectCount,
      totalIncorrectCount: practiceHistory.totalIncorrectCount,    
      listName: listName, // Nombre de la lista por defecto  
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'pronunciation': pronunciation,
      'spelling': spelling,
      'category_id': categoryId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'last_practice': lastPractice?.toIso8601String(),
      'lists': lists,
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'total_incorrect_count': totalIncorrectCount,
      'list_name': listName, // <--  Añade el nombre de la lista aquí
    };
  }

  factory WordPractice.fromMap(Map<String, dynamic> map, {List<String>? lists}) {
    return WordPractice(
      id: map['id'] ?? 0,
      word: map['word'],
      translation: map['translation'], 
      pronunciation: map['pronunciation'],
      spelling: map['spelling'],
      categoryId: map['category_id'],
      notes: map['notes'],
      createdAt: map['created_at'] is String
        ? DateTime.parse(map['created_at'])
        : map['created_at'],
      lastPractice: map['last_practice'] is String
        ? DateTime.parse(map['last_practice'])
        : map['last_practice'], //  <--  Comprueba el tipo
      lists: lists ?? [],
      correctCount: map['correct_count'] ?? 0,
      incorrectCount: map['incorrect_count'] ?? 0,
      totalIncorrectCount: map['total_incorrect_count'] ?? 0,
      listName: map['list_name'] ?? '', // <--  Añade el nombre de la lista aquí
    );
  }

  @override
    String toString() {
    return 'Word{id: $id, word: $word, translation: $translation, spelling: $spelling, createdAt: $createdAt, lists: $lists}';
    }
}
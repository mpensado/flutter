// word.dart (domain/entities/word.dart)

class Word {
  final int? id;
  final String word;
  final String translation;
  final String? pronunciation;
  final String spelling;
  final int? categoryId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastPractice;
  final int correctCount;     // Contador de aciertos
  final int incorrectCount;   // Contador de errores (para espaciado)
  final int totalIncorrectCount; // Contador total de errores

  Word({
    this.id,
    required this.word,
    required this.translation,
    this.pronunciation,
    required this.spelling,
    this.categoryId,
    this.notes,
    required this.createdAt,
    this.lastPractice,
    this.correctCount = 0,    // Valor inicial 0
    this.incorrectCount = 0,  // Valor inicial 0
    this.totalIncorrectCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'pronunciation': pronunciation,
      'spelling': spelling,
      'category_id': categoryId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'last_practice': lastPractice?.toIso8601String(),
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'total_incorrect_count': totalIncorrectCount,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'],
      translation: map['translation'],
      pronunciation: map['pronunciation'],
      spelling: map['spelling'],
      categoryId: map['category_id'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      lastPractice: map['last_practice'] != null
          ? DateTime.parse(map['last_practice'])
          : null,
      correctCount: map['correct_count'] ?? 0,  // Valor por defecto 0
      incorrectCount: map['incorrect_count'] ?? 0, // Valor por defecto 0
      totalIncorrectCount: map['total_incorrect_count'] ?? 0,
    );
  }
}
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
  final List<String> lists; //  Lista para clasificacion

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
    this.lists = const [], // Lista vacía por defecto
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
      // 'lists' NO se incluye aquí. Se maneja en la tabla word_lists.
    };
  }
    factory Word.fromMap(Map<String, dynamic> map, {List<String>? lists}) {
    return Word(
      id: map['id'],
      word: map['word'],
      translation: map['translation'],
      pronunciation: map['pronunciation'],
      spelling: map['spelling'],
      categoryId: map['category_id'],
      notes: map['notes'],
      createdAt: map['created_at'],
      lastPractice: map['last_practice'] != null
          ? DateTime.parse(map['last_practice'])
          : null,
      correctCount: map['correct_count'] ?? 0,
      incorrectCount: map['incorrect_count'] ?? 0,
      totalIncorrectCount: map['total_incorrect_count'] ?? 0,
      lists: lists ?? [], // Usa el valor proporcionado, o una lista vacía
    );
  }

    Word copyWith({
    int? id,
    String? word,
    String? translation,
    String? pronunciation,
    String? spelling,
    int? categoryId,
    String? notes,
    DateTime? createdAt,
    DateTime? lastPractice,
    int? correctCount,
    int? incorrectCount,
      int? totalIncorrectCount,
    List<String>? lists,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      pronunciation: pronunciation ?? this.pronunciation,
      spelling: spelling ?? this.spelling,
      categoryId: categoryId ?? this.categoryId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastPractice: lastPractice ?? this.lastPractice,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      totalIncorrectCount: totalIncorrectCount ?? this.totalIncorrectCount,
      lists: lists ?? this.lists,
    );
  }

    @override
    String toString() {
    return 'Word{id: $id, word: $word, translation: $translation, spelling: $spelling, createdAt: $createdAt, lists: $lists}';
    }
}
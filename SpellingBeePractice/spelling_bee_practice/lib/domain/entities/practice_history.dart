class PracticeHistory {
  final int? id;
  final int wordId;
  final int sessionId;
  final bool isCorrect;
  final DateTime practicedAt;
  final String sessionType; //  Columna

  PracticeHistory({
    this.id,
    required this.wordId,
    required this.sessionId,
    required this.isCorrect,
    required this.practicedAt,
    required this.sessionType, // Añadido al constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'session_id': sessionId,
      'is_correct': isCorrect ? 1 : 0,
      'practiced_at': practicedAt.toIso8601String(),
      'session_type': sessionType, // Añadido al mapa
    };
  }

  factory PracticeHistory.fromMap(Map<String, dynamic> map) {
    return PracticeHistory(
      id: map['id'],
      wordId: map['word_id'],
      sessionId: map['session_id'],
      isCorrect: map['is_correct'] == 1,
      practicedAt: DateTime.parse(map['practiced_at']),
      sessionType: map['session_type'], // Añadido desde el mapa
    );
  }
}
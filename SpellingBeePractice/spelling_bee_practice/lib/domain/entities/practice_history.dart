class PracticeHistory {
  final int? id;
  final int wordId;
  final int sessionId;
  final bool isCorrect;
  final DateTime practicedAt;
  final String sessionType; 
  final int correctCount;     // Contador de aciertos
  final int incorrectCount;   // Contador de errores (para espaciado)
  final int totalIncorrectCount; 

  PracticeHistory({
    this.id,
    required this.wordId,
    required this.sessionId,
    required this.isCorrect,
    required this.practicedAt,
    required this.sessionType,
    required this.correctCount,
    required this.incorrectCount, 
    required this.totalIncorrectCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word_id': wordId,
      'session_id': sessionId,
      'is_correct': isCorrect ? 1 : 0,
      'practiced_at': practicedAt.toIso8601String(),
      'session_type': sessionType,
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'total_incorrect_count': totalIncorrectCount,
    };
  }

  factory PracticeHistory.fromMap(Map<String, dynamic> map) {
    return PracticeHistory(
      id: map['id'],
      wordId: map['word_id'],
      sessionId: map['session_id'],
      isCorrect: map['is_correct'] == 1,
      practicedAt: DateTime.parse(map['practiced_at']),
      sessionType: map['session_type'],
      correctCount: map['correct_count'] ?? 0,
      incorrectCount: map['incorrect_count'] ?? 0,
      totalIncorrectCount: map['total_incorrect_count'] ?? 0,
    );
  }
}
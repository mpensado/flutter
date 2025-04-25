import 'package:spelling_bee_practice/domain/entities/practice_history.dart';

class WordPracticeHistory {
  final int wordId;
  final int? sessionId;
  final bool? isCorrect;
  final DateTime? practicedAt;
  final String? sessionType;
  final int? correctCount;
  final int? incorrectCount;
  final int? totalIncorrectCount;

  WordPracticeHistory({
    required this.wordId,
    this.sessionId,
    this.isCorrect,
    this.practicedAt,
    this.sessionType,
    this.correctCount,
    this.incorrectCount,
    this.totalIncorrectCount,
  });

  factory WordPracticeHistory.fromMap(Map<String, dynamic> map) {
    return WordPracticeHistory(
      wordId: map['word_id'] ?? map['id'],
      sessionId: map['session_id'],
      isCorrect: map['is_correct'] == 1,
      practicedAt: map['practiced_at'] != null ? DateTime.parse(map['practiced_at']) : null,
      sessionType: map['session_type'],
      correctCount: map['correct_count'],
      incorrectCount: map['incorrect_count'],
      totalIncorrectCount: map['total_incorrect_count'],
    );
  }

  factory WordPracticeHistory.fromWordPractice(PracticeHistory? practiceHistory) {
    return WordPracticeHistory(
      wordId: practiceHistory!.wordId, // Suponiendo que WordPractice tiene un 'id'
      sessionId: practiceHistory.sessionId,
      isCorrect: practiceHistory.isCorrect,
      practicedAt: practiceHistory.practicedAt,
      sessionType: practiceHistory.sessionType,
      correctCount: practiceHistory.correctCount,
      incorrectCount: practiceHistory.incorrectCount,
      totalIncorrectCount: practiceHistory.totalIncorrectCount,
    );
  }
}
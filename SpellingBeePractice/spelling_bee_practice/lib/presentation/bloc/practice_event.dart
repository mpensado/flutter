import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/domain/entities/word.dart';
import 'package:spelling_bee_practice/domain/entities/word_practice.dart';

abstract class PracticeEvent {}

  class LoadWordsEvent extends PracticeEvent {
    final PracticeSession? selectedSession;

    LoadWordsEvent(this.selectedSession);
  }

  class RecordPracticeEvent extends PracticeEvent {
    final WordPractice word;
    final bool isCorrect;
    final PracticeSession? session;

    RecordPracticeEvent(this.word, this.isCorrect, this.session);
  }

  class RemoveWordEvent extends PracticeEvent {
    final Word word;
    final PracticeSession session;

    RemoveWordEvent(this.word, this.session);
  }

  class ChangeFilterEvent extends PracticeEvent {
    final String filter;

    ChangeFilterEvent(this.filter);
  }
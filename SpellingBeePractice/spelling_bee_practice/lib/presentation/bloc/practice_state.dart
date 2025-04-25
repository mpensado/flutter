import 'package:spelling_bee_practice/domain/entities/word_practice.dart';

abstract class PracticeState {}

  class PracticeInitial extends PracticeState {}

  class PracticeLoading extends PracticeState {}

  class PracticeLoaded extends PracticeState {
    final List<WordPractice> words;
    final String filter;
    final List<String> lists;

    PracticeLoaded({required this.words, required this.filter, required this.lists});

    PracticeLoaded copyWith({
      List<WordPractice>? words,
      String? filter,
      List<String>? lists,
    }) {
      return PracticeLoaded(
        words: words ?? this.words,
        filter: filter ?? this.filter,
        lists: lists ?? this.lists,
      );
    }
  }

  class PracticeError extends PracticeState {
    final String message;

    //PracticeError(this.message);

    PracticeError({required this.message});
  }
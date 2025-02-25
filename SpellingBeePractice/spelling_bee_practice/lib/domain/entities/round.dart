// round.dart (domain/entities/round.dart)

class Round {
  final int roundNumber;
  final int numberOfWords;
  final bool canRepeat;
  final bool canPause;

  Round({
    required this.roundNumber,
    required this.numberOfWords,
    required this.canRepeat,
    required this.canPause,
  });
}
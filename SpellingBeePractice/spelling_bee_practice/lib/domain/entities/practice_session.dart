// practice_session.dart (domain/entities/practice_session.dart)

class PracticeSession {
  final int? id;
  final String name;
  final DateTime createdAt;
  final List<int> wordIds;

  PracticeSession({
    this.id,
    required this.name,
    required this.createdAt,
    required this.wordIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'word_ids':
          wordIds.join(','), // Guardamos los IDs como string separado por comas
    };
  }

  factory PracticeSession.fromMap(Map<String, dynamic> map) {
    List<int> parseWordIds(dynamic wordIdsData) {
      if (wordIdsData is String) {
        return wordIdsData
            .split(',')
            .where((str) => str.isNotEmpty)
            .map((str) {
              String trimmedStr = str.trim();
              try {
                return int.parse(trimmedStr);
              } catch (e) {
                print("Error al parsear: '$trimmedStr'. Error: $e");
                return 0; // or handle as needed
              }
            })
            .whereType<int>()
            .toList();
      } else if (wordIdsData is List) {
        return wordIdsData.map((e) => int.parse(e.toString())).toList();
      }
      return [];
    }

    return PracticeSession(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      wordIds: parseWordIds(map['word_ids']),
    );
  }
}
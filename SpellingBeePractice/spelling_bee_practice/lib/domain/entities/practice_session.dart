class PracticeSession {
  final int id;
  final String name;
  final DateTime createdAt;
  final List<int> wordIds;
  bool isFixed; // Ahora isFixed es una propiedad normal, NO final.

  PracticeSession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.wordIds,
    this.isFixed = false, // Valor predeterminado: false
  });

    factory PracticeSession.fromMap(Map<String, dynamic> map) {
        return PracticeSession(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        wordIds: (map['word_ids'] as String?) //Manejo de null
            ?.split(',')
            .where((id) => id.isNotEmpty)
            .map((id) => int.parse(id))
            .toList() ?? [],//Si es nulo, devuelve lista vacia
        );
    }

  @override
  String toString() {
    return 'PracticeSession{id: $id, name: $name, createdAt: $createdAt, wordIds: $wordIds, isFixed: $isFixed}';
  }

  // Método para convertir la instancia a un mapa (para la base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'wordIds': wordIds.join(','),
      'isFixed': isFixed ? 1 : 0, // Importante: Convertir de booleano a entero
    };
  }

  // Método copyWith para crear una copia con valores modificados
  PracticeSession copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    List<int>? wordIds,
    bool? isFixed,
  }) {
    return PracticeSession(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      wordIds: wordIds ?? this.wordIds,
      isFixed: isFixed ?? this.isFixed,
    );
  }
}
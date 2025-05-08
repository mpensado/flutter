class UserModel {
  final String userId;
  final String? nombre;
  final String? email;

  UserModel({required this.userId, this.nombre, this.email});

  // Método para crear un UserModel desde un mapa (DocumentSnapshot de Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] ?? '',
      nombre: map['nombre'],
      email: map['email'],
    );
  }

  // Método para convertir un UserModel a un mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'nombre': nombre,
      'email': email,
    };
  }
}
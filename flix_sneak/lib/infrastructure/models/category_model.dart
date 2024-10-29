class CategoryModel {
  CategoryModel({
    required this.name,
    required this.imageUrl,
    required this.url,
    required this.tipo,
    required this.dependencia,
    required this.favorite
  });

  final String name;
  final String imageUrl;
  final String url;
  final String tipo;
  final String dependencia;
  bool favorite;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
        name: json['name'],
        imageUrl: json['imageUrl'],
        url: json['url'],
        tipo: json['tipo'],
        dependencia: json['dependencia'],
        favorite: json['favorite']);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'url': url,
      'tipo': tipo,
      'dependencia': dependencia,
      'favorite': favorite,
    };
  }
}

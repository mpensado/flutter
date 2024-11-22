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

  static List<CategoryModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => CategoryModel.fromJson(json)).toList();
  }

  static List<Map<String, dynamic>> toJsonList(List<CategoryModel> dtos) {
    return dtos.map((dto) => dto.toJson()).toList();
  }
}

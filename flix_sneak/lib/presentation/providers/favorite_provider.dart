import 'package:flixsneak/config/helpers/browser_tools.dart';
import 'package:flixsneak/infrastructure/models/category_model.dart';
import 'package:flutter/material.dart';

class FavoriteProvider extends ChangeNotifier {
  List<CategoryModel> favorities = [];
  Future<void> switchFavorite(List<CategoryModel> categories, String name) async {
    int index = categories.indexWhere((category) => category.name == name);

    if (index != -1) {
      categories[index].favorite = !categories[index].favorite;
      BrowserTools.escribirEnArchivo(categories);
      notifyListeners();
    }
  }
}

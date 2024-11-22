import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sneak_flix/config/helpers/tools.dart';
import 'package:sneak_flix/infrastructure/models/category_model';

class AppProvider extends ChangeNotifier {
  List<CategoryModel> categories = [];
  List<CategoryModel> actualViewList = [];
  String actualName = "home";
  bool showReturnStatus = false;
  bool favoritePage = false;

  //double scrollHomePosition = 0;
  //double scrollFavoritePosition = 0;

  late ScrollController scrollCurrentController = ScrollController(initialScrollOffset: 0);
  //---------------------------------------
  Future<void> switchFavorite(String name) async {
    int index = categories.indexWhere((category) => category.name == name);

    if (index != -1) {
      categories[index].favorite = !categories[index].favorite;
      //favoritePage = categories[index].favorite;
      Tools.escribirEnArchivo(categories);


      notifyListeners();
    }
  }

  Future<void> getCategories() async {
    if (categories.isEmpty) {
      await loadCategories();
    }
    if (favoritePage) {
      actualViewList = categories
          .where((category) =>
              category.favorite == true)
          .toList();
    } else {
      actualViewList = categories
          .where((category) => category.dependencia == actualName)
          .toList();
    }
  }

  bool getShowReturnStatus() {
    return showReturnStatus;
  }

  bool getIsHome() {
    return actualName == 'home';
  }

  Future<void> setNameCategories(String name) async {
    actualName = name;
    showReturnStatus = actualName != "home";
    notifyListeners();
  }

  Future<void> updateStatus(String name) async {
    actualName = name;
    showReturnStatus = actualName != "home";
    getCategories();
    notifyListeners();
  }

  Future<void> notify() async {
    notifyListeners();
  }

  Future<void> loadCategories() async {
    try {
      categories = (await Tools.leerArchivo())!;
      if (categories.isEmpty) {
        await loadCategoriesLocal();
      }
      actualViewList = categories
          .where((category) => category.dependencia == actualName)
          .toList();

      Tools.escribirEnArchivo(categories);
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> loadCategoriesLocal() async {
    try {
      final String response =
          await rootBundle.loadString('assets/categories.json');
      final List<dynamic> data = json.decode(response);
      categories = data.map((item) => CategoryModel.fromJson(item)).toList();
    } catch (e) {
      print('Error loading categories: $e');
    }
  }
}

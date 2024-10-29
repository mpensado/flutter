import 'dart:convert';

import 'package:flixsneak/infrastructure/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MovieProvider extends ChangeNotifier {
  List<CategoryModel> categories = [];
  List<CategoryModel> actualViewList = [];
  String actualName = "home";
  bool showReturnStatus = false;
  //---------------------------------------
  final chatScrollController = ScrollController();

  Future<void> switchFavorite(String name) async {
    int index = categories.indexWhere((category) => category.name == name);

    if (index != -1) {
      categories[index].favorite = !categories[index].favorite;
      notifyListeners();
    }
  }

  Future<void> getCategories() async {
    if (categories.isEmpty) {
      await loadCategories();
    }
    actualViewList = categories
        .where((category) => category.dependencia == actualName)
        .toList();
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

  Future<void> loadCategories() async {
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

import 'package:flutter/material.dart';
import '../database/drift_database.dart';

class CategoriesProvider extends ChangeNotifier {
  final AppDatabase db;
  List<Category> _categories = [];

  CategoriesProvider(this.db) {
    db.watchAllCategories().listen((categories) {
      _categories = categories;
      notifyListeners();
    });
  }

  List<Category> get categories => _categories;

  Future<void> addCategory(String title, String emoji) async {
    await db.insertCategory(
      CategoriesCompanion.insert(title: title, emoji: emoji),
    );
  }

  Future<void> deleteCategory(Category category) async {
    await db.deleteCategory(category);
  }

  Future<void> updateCategory(Category category) async {
    await db.updateCategory(category);
  }
}

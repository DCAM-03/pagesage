import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/books/category.dart' as domain;
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftCategoryRepository implements domain.CategoryRepository {
  const DriftCategoryRepository(this._dao);

  final db.CategoryDao _dao;

  @override
  Stream<List<domain.BookCategory>> watchCategories() {
    return _dao.watchCategories().map(
      (rows) => rows.map(_mapCategory).toList(growable: false),
    );
  }

  @override
  Future<List<domain.BookCategory>> getCategories() async {
    final rows = await _dao.getCategories();
    return rows.map(_mapCategory).toList(growable: false);
  }

  @override
  Future<domain.BookCategory> saveCategory({
    String? id,
    String? parentId,
    required String name,
    int sortOrder = 0,
    String? icon,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('分类名称不能为空');
    }
    final existing = await getCategories();
    if (existing.any(
      (category) => category.id != id && category.name == trimmedName,
    )) {
      throw const FormatException('分类名称已存在');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    domain.BookCategory? previous;
    for (final category in existing) {
      if (category.id == id) {
        previous = category;
        break;
      }
    }
    var resolvedSortOrder = sortOrder;
    if (previous == null && sortOrder == 0 && existing.isNotEmpty) {
      resolvedSortOrder =
          existing
              .map((category) => category.sortOrder)
              .reduce((value, element) => value > element ? value : element) +
          1024;
    }
    final category = domain.BookCategory(
      id: id ?? _uuid.v4(),
      parentId: parentId,
      name: trimmedName,
      sortOrder: resolvedSortOrder,
      icon: icon,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _dao.upsertCategory(
      db.CategoriesCompanion.insert(
        id: category.id,
        parentId: Value(category.parentId),
        name: category.name,
        sortOrder: Value(category.sortOrder),
        icon: Value(category.icon),
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
      ),
    );
    return category;
  }

  @override
  Future<void> deleteCategory(String id, {String? moveBooksToCategoryId}) {
    return _dao.deleteCategory(
      id,
      moveBooksToCategoryId: moveBooksToCategoryId,
    );
  }

  domain.BookCategory _mapCategory(db.CategoryRow row) {
    return domain.BookCategory(
      id: row.id,
      parentId: row.parentId,
      name: row.name,
      sortOrder: row.sortOrder,
      icon: row.icon,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

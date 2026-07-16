final class BookCategory {
  const BookCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.icon,
  });

  final String id;
  final String? parentId;
  final String name;
  final int sortOrder;
  final String? icon;
  final int createdAt;
  final int updatedAt;
}

abstract interface class CategoryRepository {
  Stream<List<BookCategory>> watchCategories();

  Future<List<BookCategory>> getCategories();

  Future<BookCategory> saveCategory({
    String? id,
    String? parentId,
    required String name,
    int sortOrder,
    String? icon,
  });

  Future<void> deleteCategory(String id, {String? moveBooksToCategoryId});
}

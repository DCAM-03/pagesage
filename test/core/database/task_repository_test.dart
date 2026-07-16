import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_content_repositories.dart';
import 'package:pagesage/core/tasks/task_models.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTaskRepository(database.taskDao);
  });

  tearDown(() async {
    await database.close();
  });

  test('updates import task status with target path and book id', () async {
    final task = await repository.saveTask(
      id: 'task-1',
      type: PageSageTaskType.importBook,
      status: PageSageTaskStatus.running,
      sourcePath: '/source/book.epub',
      progress: 0.1,
      message: '正在导入',
    );

    await repository.updateStatus(
      id: task.id,
      status: PageSageTaskStatus.indexing,
      progress: 0.82,
      targetPath: '/library/book.epub',
      bookId: 'book-1',
      message: '正在建立索引',
    );

    final saved = await repository.getTasks();

    expect(saved.single.status, PageSageTaskStatus.indexing);
    expect(saved.single.progress, 0.82);
    expect(saved.single.sourcePath, '/source/book.epub');
    expect(saved.single.targetPath, '/library/book.epub');
    expect(saved.single.bookId, 'book-1');
    expect(saved.single.message, '正在建立索引');
  });
}

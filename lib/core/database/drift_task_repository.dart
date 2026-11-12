import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../tasks/task_models.dart' as domain;
import 'app_database.dart' as db;

const _uuid = Uuid();

final class DriftTaskRepository implements domain.TaskRepository {
  const DriftTaskRepository(this._dao);

  final db.TaskDao _dao;

  @override
  Stream<List<domain.PageSageTask>> watchTasks() {
    return _dao.watchTasks().map(
      (rows) => rows.map(_mapTask).toList(growable: false),
    );
  }

  @override
  Future<List<domain.PageSageTask>> getTasks() async {
    final rows = await _dao.getTasks();
    return rows.map(_mapTask).toList(growable: false);
  }

  @override
  Future<domain.PageSageTask> saveTask({
    String? id,
    required domain.PageSageTaskType type,
    required domain.PageSageTaskStatus status,
    String? sourcePath,
    String? targetPath,
    String? bookId,
    double progress = 0,
    String? message,
    String? error,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = domain.PageSageTask(
      id: id ?? _uuid.v4(),
      type: type,
      status: status,
      sourcePath: sourcePath,
      targetPath: targetPath,
      bookId: bookId,
      progress: progress,
      message: message,
      error: error,
      createdAt: now,
      updatedAt: now,
    );
    await _dao.upsertTask(
      db.ImportTasksCompanion.insert(
        id: task.id,
        type: task.type.value,
        status: task.status.value,
        sourcePath: Value(task.sourcePath),
        targetPath: Value(task.targetPath),
        bookId: Value(task.bookId),
        progress: Value(task.progress),
        message: Value(task.message),
        error: Value(task.error),
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
      ),
    );
    return task;
  }

  @override
  Future<void> updateStatus({
    required String id,
    required domain.PageSageTaskStatus status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
    bool clearError = false,
  }) {
    return _dao.updateStatus(
      id: id,
      status: status.value,
      progress: progress,
      targetPath: targetPath,
      bookId: bookId,
      message: message,
      error: error,
      clearError: clearError,
    );
  }

  @override
  Future<void> clearCompleted() {
    return _dao.clearCompleted();
  }

  domain.PageSageTask _mapTask(db.ImportTaskRow row) {
    return domain.PageSageTask(
      id: row.id,
      type: domain.PageSageTaskType.fromValue(row.type),
      status: domain.PageSageTaskStatus.fromValue(row.status),
      sourcePath: row.sourcePath,
      targetPath: row.targetPath,
      bookId: row.bookId,
      progress: row.progress,
      message: row.message,
      error: row.error,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

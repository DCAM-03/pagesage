enum PageSageTaskType {
  importBook('import'),
  metadata('metadata'),
  indexBook('index'),
  rebuildIndex('rebuildIndex'),
  exportNotes('exportNotes'),
  backup('backup'),
  restore('restore');

  const PageSageTaskType(this.value);

  final String value;

  static PageSageTaskType fromValue(String value) {
    return values.firstWhere(
      (type) => type.value == value,
      orElse: () => PageSageTaskType.importBook,
    );
  }
}

enum PageSageTaskStatus {
  queued('queued'),
  running('running'),
  indexing('indexing'),
  done('done'),
  failed('failed'),
  cancelled('cancelled');

  const PageSageTaskStatus(this.value);

  final String value;

  static PageSageTaskStatus fromValue(String value) {
    return values.firstWhere(
      (status) => status.value == value,
      orElse: () => PageSageTaskStatus.queued,
    );
  }
}

final class PageSageTask {
  const PageSageTask({
    required this.id,
    required this.type,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.sourcePath,
    this.targetPath,
    this.bookId,
    this.message,
    this.error,
  });

  final String id;
  final PageSageTaskType type;
  final PageSageTaskStatus status;
  final String? sourcePath;
  final String? targetPath;
  final String? bookId;
  final double progress;
  final String? message;
  final String? error;
  final int createdAt;
  final int updatedAt;
}

abstract interface class TaskRepository {
  Stream<List<PageSageTask>> watchTasks();

  Future<List<PageSageTask>> getTasks();

  Future<PageSageTask> saveTask({
    String? id,
    required PageSageTaskType type,
    required PageSageTaskStatus status,
    String? sourcePath,
    String? targetPath,
    String? bookId,
    double progress,
    String? message,
    String? error,
  });

  Future<void> updateStatus({
    required String id,
    required PageSageTaskStatus status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
  });

  Future<void> clearCompleted();
}

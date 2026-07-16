import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/features/tasks/presentation/task_center_page.dart';

void main() {
  testWidgets(
    'TaskCenterPage handles long task text on narrow large-text screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(
              _FakeTaskRepository([
                const PageSageTask(
                  id: 'task-long',
                  type: PageSageTaskType.importBook,
                  status: PageSageTaskStatus.running,
                  sourcePath:
                      r'D:\very-long-folder-name\another-long-folder-name\一本标题特别特别特别长的 EPUB 文件用于测试布局不会溢出.epub',
                  targetPath:
                      r'D:\PageSage\library\very-long-generated-target-file-name.epub',
                  progress: 0.42,
                  message: '正在处理一个非常非常长的任务消息，用于验证任务中心在窄屏和字体放大时不会重叠或横向溢出',
                  createdAt: 1,
                  updatedAt: 2,
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 720),
                textScaler: TextScaler.linear(1.4),
              ),
              child: const TaskCenterPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('任务中心'), findsOneWidget);
      expect(find.text('进行中'), findsWidgets);

      await tester.tap(find.byTooltip('任务操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看详情'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('任务详情'), findsOneWidget);
      expect(find.text('来源'), findsOneWidget);
      expect(find.text('目标'), findsOneWidget);
    },
  );
}

final class _FakeTaskRepository implements TaskRepository {
  const _FakeTaskRepository(this.tasks);

  final List<PageSageTask> tasks;

  @override
  Future<void> clearCompleted() async {}

  @override
  Future<List<PageSageTask>> getTasks() async => tasks;

  @override
  Future<PageSageTask> saveTask({
    String? id,
    required PageSageTaskType type,
    required PageSageTaskStatus status,
    String? sourcePath,
    String? targetPath,
    String? bookId,
    double progress = 0,
    String? message,
    String? error,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return PageSageTask(
      id: id ?? 'task-new',
      type: type,
      status: status,
      progress: progress,
      createdAt: now,
      updatedAt: now,
      sourcePath: sourcePath,
      targetPath: targetPath,
      bookId: bookId,
      message: message,
      error: error,
    );
  }

  @override
  Future<void> updateStatus({
    required String id,
    required PageSageTaskStatus status,
    double? progress,
    String? targetPath,
    String? bookId,
    String? message,
    String? error,
  }) async {}

  @override
  Stream<List<PageSageTask>> watchTasks() => Stream.value(tasks);
}

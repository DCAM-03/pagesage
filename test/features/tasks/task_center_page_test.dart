import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/app/theme/app_theme.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/domain/books/reader_settings.dart';
import 'package:pagesage/domain/books/settings_repository.dart';
import 'package:pagesage/features/tasks/presentation/task_center_page.dart';

import '../../support/reader_workbench_capture.dart';

void main() {
  setUpAll(() async {
    if (captureWorkbench) await loadWorkbenchCaptureFonts();
  });

  Future<void> pumpTaskCenter(
    WidgetTester tester,
    List<PageSageTask> tasks, {
    double width = 800,
    double height = 600,
    double textScale = 1,
    bool dark = false,
  }) async {
    final database = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(database.close);
    });
    final theme = dark ? AppTheme.dark() : AppTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsRepositoryProvider.overrideWithValue(
            const _FakeSettingsRepository(),
          ),
          taskRepositoryProvider.overrideWithValue(_FakeTaskRepository(tasks)),
        ],
        child: MaterialApp(
          theme: captureWorkbench
              ? theme.copyWith(
                  chipTheme: theme.chipTheme.copyWith(
                    labelStyle: theme.chipTheme.labelStyle?.copyWith(
                      fontFamily: 'Segoe UI',
                    ),
                  ),
                )
              : theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: workbenchCaptureKey, child: child!),
          ),
          home: const TaskCenterPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'TaskCenterPage handles long task text on narrow large-text screens',
    (tester) async {
      await pumpTaskCenter(
        tester,
        [
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
        ],
        width: 360,
        height: 720,
        textScale: 1.4,
      );

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
      await tester.scrollUntilVisible(
        find.text('目标'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('目标'), findsOneWidget);
    },
  );

  testWidgets('an OCR task exposes failed-page retry and result clearing', (
    tester,
  ) async {
    await pumpTaskCenter(tester, [
      const PageSageTask(
        id: 'task-ocr',
        type: PageSageTaskType.ocrPages,
        status: PageSageTaskStatus.partial,
        bookId: 'book-1',
        progress: 1,
        message: '完成 2 页 · 失败 1',
        createdAt: 1,
        updatedAt: 2,
      ),
    ]);
    expect(find.text('部分完成 1'), findsOneWidget);
    expect(find.text('完成 0'), findsOneWidget);
    expect(find.text('已处理 100%'), findsOneWidget);
    await captureWorkbenchWidget(tester, 'task-center-ocr-partial');

    await tester.tap(find.byTooltip('任务操作'));
    await tester.pumpAndSettle();

    expect(find.text('重试失败页'), findsOneWidget);
    expect(find.text('清除 OCR 结果'), findsOneWidget);
    expect(find.text('继续识别'), findsNothing);
    await captureWorkbenchWidget(tester, 'task-center-ocr-partial-actions');
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused OCR tasks remain visible on narrow large-text screens', (
    tester,
  ) async {
    await pumpTaskCenter(
      tester,
      [
        const PageSageTask(
          id: 'task-paused',
          type: PageSageTaskType.ocrPages,
          status: PageSageTaskStatus.paused,
          bookId: 'book-1',
          progress: 0.4,
          message: '上次识别中断，可继续',
          createdAt: 1,
          updatedAt: 2,
        ),
      ],
      width: 390,
      height: 780,
      textScale: 1.5,
      dark: true,
    );
    expect(find.text('已暂停 1'), findsOneWidget);
    expect(find.text('进行中 0'), findsOneWidget);
    expect(find.text('已处理 40%'), findsOneWidget);
    await captureWorkbenchWidget(tester, 'task-center-ocr-paused-narrow');

    await tester.tap(find.byTooltip('任务操作'));
    await tester.pumpAndSettle();
    expect(find.text('继续识别'), findsOneWidget);
    expect(find.text('重试失败页'), findsNothing);
    expect(find.text('暂停识别'), findsNothing);
    await captureWorkbenchWidget(tester, 'task-center-ocr-paused-actions');
    expect(tester.takeException(), isNull);
  });
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
    bool clearError = false,
  }) async {}

  @override
  Stream<List<PageSageTask>> watchTasks() => Stream.value(tasks);
}

/// Enough for the header's theme switch: the value it reads, and a save that
/// goes nowhere.
final class _FakeSettingsRepository implements SettingsRepository {
  const _FakeSettingsRepository();

  @override
  Future<ReaderSettings> getReaderSettings() async => const ReaderSettings();

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) async {}

  @override
  Stream<ReaderSettings> watchReaderSettings() {
    return Stream.value(const ReaderSettings());
  }
}

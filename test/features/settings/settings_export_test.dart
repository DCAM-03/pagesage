import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/database_providers.dart';
import 'package:pagesage/core/files/app_paths.dart';
import 'package:pagesage/core/files/file_providers.dart';
import 'package:pagesage/core/platform/file_picker_service.dart';
import 'package:pagesage/core/platform/open_file_location_service.dart';
import 'package:pagesage/core/platform/platform_providers.dart';
import 'package:pagesage/core/security/secure_store.dart';
import 'package:pagesage/core/tasks/task_models.dart';
import 'package:pagesage/features/settings/presentation/settings_page.dart';
import 'package:pagesage/features/export/application/export_providers.dart';

void main() {
  for (final outcome in ['success', 'cancel', 'failure']) {
    testWidgets(
      'Android export $outcome finishes with the correct task state',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 1000);
        addTearDown(tester.view.reset);
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('pagesage-android-export-'),
        ))!;
        final database = AppDatabase.forTesting(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        const channel = MethodChannel('test/android/export');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var saveCalls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          saveCalls++;
          expect(call.method, 'saveExport');
          final file = File(call.arguments['sourcePath'] as String);
          expect(await file.readAsString(), contains('# PageSage 笔记导出'));
          if (outcome == 'failure') {
            throw PlatformException(code: 'export_write_failed');
          }
          return outcome == 'cancel' ? null : 'content://provider/saved.md';
        });
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            appPathsProvider.overrideWithValue(
              AppPaths(overrideRoot: directory),
            ),
            secureStoreProvider.overrideWithValue(SecureStore.memory()),
            filePickerServiceProvider.overrideWithValue(
              FilePickerService(isAndroid: true, filesChannel: channel),
            ),
            openFileLocationServiceProvider.overrideWithValue(
              OpenFileLocationService(isWindows: false, isLinux: false),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: SettingsPage()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('隐私与数据').first);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('导出全部笔记'));
          await tester.tap(find.text('导出全部笔记'));
          List<PageSageTask> tasks = [];
          for (var attempt = 0; attempt < 80; attempt++) {
            await tester.pump();
            tasks = (await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return container.read(taskRepositoryProvider).getTasks();
            }))!;
            if (tasks.isNotEmpty &&
                tasks.single.status != PageSageTaskStatus.running) {
              break;
            }
          }
          await tester.pumpAndSettle();
          expect(saveCalls, 1);
          expect(tasks.single.status, switch (outcome) {
            'success' => PageSageTaskStatus.done,
            'cancel' => PageSageTaskStatus.cancelled,
            _ => PageSageTaskStatus.failed,
          });
          expect(find.text('打开位置'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          messenger.setMockMethodCallHandler(channel, null);
          container.dispose();
          await tester.runAsync(database.close);
          await tester.runAsync(() => directory.delete(recursive: true));
        }
      },
    );
  }

  testWidgets(
    'restoring through settings succeeds after closing the old database',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('pagesage-settings-restore-'),
      ))!;
      final paths = AppPaths(overrideRoot: root);
      final file = (await tester.runAsync(paths.databaseFile))!;
      await tester.runAsync(() => file.parent.create(recursive: true));
      final databases = <AppDatabase>[];
      late File backup;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final database = AppDatabase.forTesting(
              DatabaseConnection(
                NativeDatabase(file),
                closeStreamsSynchronously: true,
              ),
            );
            databases.add(database);
            return database;
          }),
          appPathsProvider.overrideWithValue(paths),
          secureStoreProvider.overrideWithValue(SecureStore.memory()),
          filePickerServiceProvider.overrideWithValue(
            FilePickerService(adapter: _RestorePicker(() => backup.path)),
          ),
        ],
      );
      try {
        await tester.runAsync(() async {
          final database = container.read(appDatabaseProvider);
          await database
              .into(database.notes)
              .insert(
                NotesCompanion.insert(
                  id: 'note',
                  content: '备份中的笔记',
                  noteType: 'text',
                  createdAt: 1,
                  updatedAt: 1,
                ),
              );
          backup = await container
              .read(exportServiceProvider)
              .backupDatabaseZip(targetPath: '${root.path}/backup.zip');
          await database.customStatement(
            "UPDATE notes SET content = '后来修改的笔记'",
          );
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsPage()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('隐私与数据').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('恢复数据库备份'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢复数据库备份'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('恢复'));
        for (
          var attempt = 0;
          attempt < 200 && find.text('恢复完成').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump();
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
        }
        await tester.pumpAndSettle();
        expect(find.text('恢复完成'), findsOneWidget);
        expect(find.text('恢复失败：备份文件无效或无法写入'), findsNothing);
        final content = await tester.runAsync(() async {
          final database = container.read(appDatabaseProvider);
          return (await database.select(database.notes).getSingle()).content;
        });
        expect(content, '备份中的笔记');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.runAsync(() async {
          for (final database in databases) {
            await database.close();
          }
          await root.delete(recursive: true);
        });
      }
    },
  );

  for (final outcome in ['success', 'cancel', 'pickerError', 'writeError']) {
    testWidgets(
      'settings export handles $outcome without losing existing data',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('pagesage-settings-export-'),
        ))!;
        final database = AppDatabase.forTesting(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        final destination = File('${directory.path}/用户笔记.md');
        await tester.runAsync(() => destination.writeAsString('原导出'));
        final gate = Completer<String?>();
        final picker = _Picker(gate);
        final opened = <List<String>>[];
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            appPathsProvider.overrideWithValue(
              AppPaths(overrideRoot: directory),
            ),
            secureStoreProvider.overrideWithValue(SecureStore.memory()),
            filePickerServiceProvider.overrideWithValue(
              FilePickerService(adapter: picker),
            ),
            openFileLocationServiceProvider.overrideWithValue(
              OpenFileLocationService(
                isWindows: false,
                isLinux: true,
                runner: (executable, arguments) async {
                  expect(executable, 'xdg-open');
                  opened.add(arguments);
                  return ProcessResult(1, 0, '', '');
                },
              ),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: SettingsPage()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('隐私与数据').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('导出全部笔记'));
          await tester.pump();
          await tester.tap(find.text('导出全部笔记'));
          expect(picker.calls, 1);
          if (outcome == 'pickerError') {
            gate.completeError(const FileSystemException('picker unavailable'));
          } else if (outcome == 'cancel') {
            gate.complete(null);
          } else if (outcome == 'writeError') {
            final blocked = Directory('${directory.path}/blocked.md');
            await tester.runAsync(blocked.create);
            gate.complete(blocked.path);
          } else {
            gate.complete(destination.path);
          }
          List<PageSageTask> tasks = [];
          for (var attempt = 0; attempt < 50; attempt++) {
            await tester.pump();
            tasks = (await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return container.read(taskRepositoryProvider).getTasks();
            }))!;
            if (outcome == 'cancel' ||
                outcome == 'pickerError' ||
                tasks.any(
                  (task) =>
                      task.status == PageSageTaskStatus.done ||
                      task.status == PageSageTaskStatus.failed,
                )) {
              break;
            }
          }
          await tester.pumpAndSettle();
          if (outcome == 'success') {
            expect(
              await tester.runAsync(destination.readAsString),
              contains('# PageSage 笔记导出'),
            );
            expect(tasks.single.status, PageSageTaskStatus.done);
            await tester.tap(find.text('打开位置'));
            for (var attempt = 0; attempt < 20 && opened.isEmpty; attempt++) {
              await tester.pump();
              await tester.runAsync(() async {
                await Future<void>.delayed(const Duration(milliseconds: 20));
              });
            }
            expect(opened.single, [directory.path]);
          } else {
            expect(await tester.runAsync(destination.readAsString), '原导出');
            if (outcome == 'writeError') {
              expect(tasks.single.status, PageSageTaskStatus.failed);
              expect(find.text('导出失败：请检查保存位置、写入权限和剩余空间'), findsOneWidget);
            } else {
              expect(tasks, isEmpty);
            }
            if (outcome == 'pickerError') {
              expect(find.text('无法选择文件，请重试或检查保存位置权限'), findsOneWidget);
            }
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await tester.runAsync(database.close);
          await tester.runAsync(() => directory.delete(recursive: true));
        }
      },
    );
  }
}

class _Picker implements FilePickerAdapter {
  _Picker(this.gate);
  final Completer<String?> gate;
  int calls = 0;

  @override
  Future<String?> saveFile(FileSaveRequest request) {
    calls++;
    return gate.future;
  }

  @override
  Future<List<PickedPlatformFile>> pickFiles(FilePickerRequest request) async =>
      [];

  @override
  Future<String?> pickDirectory({required String dialogTitle}) async => null;
}

class _RestorePicker implements FilePickerAdapter {
  _RestorePicker(this.path);
  final String Function() path;

  @override
  Future<List<PickedPlatformFile>> pickFiles(FilePickerRequest request) async =>
      [PickedPlatformFile(path: path(), name: 'backup.zip')];

  @override
  Future<String?> saveFile(FileSaveRequest request) async => null;

  @override
  Future<String?> pickDirectory({required String dialogTitle}) async => null;
}

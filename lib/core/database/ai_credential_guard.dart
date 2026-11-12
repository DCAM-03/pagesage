import 'dart:async';
import 'dart:io';

import '../../domain/ai/ai_models.dart';
import 'app_database.dart';

final class AiCredentialGuard {
  AiCredentialGuard(this.database);

  final AppDatabase database;
  static final Map<Object, Future<void>> _queues = {};

  Future<T> run<T>(Future<T> Function() action) async {
    final databases = await database.customSelect('PRAGMA database_list').get();
    final path = databases
        .where((row) => row.read<String>('name') == 'main')
        .first
        .read<String>('file');
    final lockFile = path.isEmpty
        ? null
        : File('${await File(path).resolveSymbolicLinks()}.credentials.lock');
    final Object key = lockFile?.path ?? database;
    final previous = _queues[key];
    final finished = Completer<void>();
    _queues[key] = finished.future;
    RandomAccessFile? handle;
    var locked = false;
    try {
      await previous;
      if (lockFile != null) {
        handle = await lockFile.open(mode: FileMode.append);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!locked) {
          try {
            await handle.lock(FileLock.exclusive);
            locked = true;
          } on FileSystemException {
            if (DateTime.now().isAfter(deadline)) {
              throw const AiProfileException('配置正在被其他窗口使用，请稍后重试');
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
      }
      return await action();
    } finally {
      try {
        if (locked) await handle?.unlock();
      } finally {
        try {
          await handle?.close();
        } finally {
          finished.complete();
          if (identical(_queues[key], finished.future)) _queues.remove(key);
        }
      }
    }
  }
}

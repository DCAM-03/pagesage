import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagesage/core/database/app_database.dart';
import 'package:pagesage/core/database/drift_ocr_job_repository.dart';
import 'package:pagesage/domain/ocr/ocr_jobs.dart';

void main() {
  late AppDatabase database;
  late DriftOcrJobRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftOcrJobRepository(database);
  });

  tearDown(() => database.close());

  test(
    'persists page order, updates checkpoints, and recovers paused work',
    () async {
      final job = await repository.createJob(
        taskId: 'task-1',
        bookId: 'book-1',
        sourceRevision: 'hash-1',
        config: const OcrJobConfig(languageHint: 'zh-Hans'),
        pageNumbers: [3, 1, 2],
        expectedCacheSignature: 'signature-1',
      );
      expect(job.status, OcrJobStatus.queued);

      final pages = await repository.getPages(job.id);
      expect(pages.map((page) => page.pageNumber), [1, 2, 3]);
      expect(
        pages.every((page) => page.status == OcrPageJobStatus.pending),
        isTrue,
      );

      await repository.updateJob(
        id: job.id,
        status: OcrJobStatus.running,
        clearReason: true,
      );
      await repository.updatePage(
        id: pages.first.id,
        status: OcrPageJobStatus.recognizing,
        attempt: 1,
      );
      await repository.updatePage(
        id: pages[1].id,
        status: OcrPageJobStatus.recognized,
        attempt: 1,
      );

      await repository.recoverInterrupted(liveTaskIds: const {});

      final recovered = await repository.getJob(job.id);
      expect(recovered?.status, OcrJobStatus.paused);
      expect(recovered?.reason, 'interrupted');
      final recoveredPages = await repository.getPages(job.id);
      expect(recoveredPages.first.status, OcrPageJobStatus.pending);
      expect(recoveredPages.first.attempt, 1);
      expect(recoveredPages[1].status, OcrPageJobStatus.recognized);
      expect((await repository.getLatestResumable('book-1'))?.id, job.id);
    },
  );

  test('a live task is not marked interrupted', () async {
    final job = await repository.createJob(
      taskId: 'task-live',
      bookId: 'book-1',
      sourceRevision: 'hash-1',
      config: const OcrJobConfig(),
      pageNumbers: [1],
      expectedCacheSignature: 'signature-1',
    );
    await repository.updateJob(
      id: job.id,
      status: OcrJobStatus.running,
      clearReason: true,
    );

    await repository.recoverInterrupted(liveTaskIds: const {'task-live'});

    expect((await repository.getJob(job.id))?.status, OcrJobStatus.running);
    await repository.deleteByBook('book-1');
    expect(await repository.getJob(job.id), isNull);
    expect(await repository.getPages(job.id), isEmpty);
  });

  test('deleteJob removes only its own job and page checkpoints', () async {
    final first = await repository.createJob(
      taskId: 'task-delete-1',
      bookId: 'book-1',
      sourceRevision: 'hash-1',
      config: const OcrJobConfig(),
      pageNumbers: [1],
      expectedCacheSignature: 'signature-1',
    );
    final second = await repository.createJob(
      taskId: 'task-delete-2',
      bookId: 'book-1',
      sourceRevision: 'hash-1',
      config: const OcrJobConfig(),
      pageNumbers: [2],
      expectedCacheSignature: 'signature-1',
    );

    await repository.deleteJob(first.id);

    expect(await repository.getJob(first.id), isNull);
    expect(await repository.getPages(first.id), isEmpty);
    expect(await repository.getJob(second.id), isNotNull);
    expect(await repository.getPages(second.id), hasLength(1));
  });
}

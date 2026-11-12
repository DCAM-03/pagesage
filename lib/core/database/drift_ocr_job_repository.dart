import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/ocr/ocr_jobs.dart';
import 'app_database.dart';

final class DriftOcrJobRepository implements OcrJobRepository {
  const DriftOcrJobRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Future<OcrJob> createJob({
    required String taskId,
    required String bookId,
    required String sourceRevision,
    required OcrJobConfig config,
    required List<int> pageNumbers,
    required String expectedCacheSignature,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.ocrJobs)
          .insert(
            OcrJobsCompanion.insert(
              id: id,
              taskId: taskId,
              bookId: bookId,
              sourceRevision: sourceRevision,
              configJson: config.encode(),
              status: const Value('queued'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (pageNumbers.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.ocrJobPages, [
            for (final pageNumber in pageNumbers)
              OcrJobPagesCompanion.insert(
                id: _uuid.v4(),
                jobId: id,
                pageNumber: pageNumber,
                expectedCacheSignature: expectedCacheSignature,
                updatedAt: now,
              ),
          ]);
        });
      }
    });
    return OcrJob(
      id: id,
      taskId: taskId,
      bookId: bookId,
      sourceRevision: sourceRevision,
      config: config,
      status: OcrJobStatus.queued,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<OcrJob?> getJob(String id) async {
    final row = await (_db.select(
      _db.ocrJobs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapJob(row);
  }

  @override
  Future<OcrJob?> getJobByTaskId(String taskId) async {
    final row = await (_db.select(
      _db.ocrJobs,
    )..where((row) => row.taskId.equals(taskId))).getSingleOrNull();
    return row == null ? null : _mapJob(row);
  }

  @override
  Future<OcrJob?> getLatestResumable(String bookId) async {
    final row =
        await (_db.select(_db.ocrJobs)
              ..where(
                (row) =>
                    row.bookId.equals(bookId) &
                    (row.status.equals('paused') |
                        row.status.equals('partial')),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _mapJob(row);
  }

  @override
  Future<List<OcrJobPage>> getPages(String jobId) async {
    final rows =
        await (_db.select(_db.ocrJobPages)
              ..where((row) => row.jobId.equals(jobId))
              ..orderBy([(row) => OrderingTerm.asc(row.pageNumber)]))
            .get();
    return rows.map(_mapPage).toList(growable: false);
  }

  @override
  Future<void> updateJob({
    required String id,
    required OcrJobStatus status,
    String? reason,
    bool clearReason = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.update(_db.ocrJobs)..where((row) => row.id.equals(id))).write(
      OcrJobsCompanion(
        status: Value(status.value),
        reason: clearReason
            ? const Value(null)
            : reason == null
            ? const Value.absent()
            : Value(reason),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> updatePage({
    required String id,
    required OcrPageJobStatus status,
    int? attempt,
    String? ocrPageId,
    String? errorCode,
    bool clearError = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.update(
      _db.ocrJobPages,
    )..where((row) => row.id.equals(id))).write(
      OcrJobPagesCompanion(
        status: Value(status.value),
        attempt: attempt == null ? const Value.absent() : Value(attempt),
        ocrPageId: ocrPageId == null ? const Value.absent() : Value(ocrPageId),
        errorCode: clearError
            ? const Value(null)
            : errorCode == null
            ? const Value.absent()
            : Value(errorCode),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> deleteJob(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.ocrJobPages,
      )..where((row) => row.jobId.equals(id))).go();
      await (_db.delete(_db.ocrJobs)..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<void> recoverInterrupted({required Set<String> liveTaskIds}) async {
    final jobs =
        await (_db.select(_db.ocrJobs)..where(
              (row) =>
                  row.status.equals('queued') | row.status.equals('running'),
            ))
            .get();
    final staleIds = [
      for (final job in jobs)
        if (!liveTaskIds.contains(job.taskId)) job.id,
    ];
    if (staleIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(
        _db.ocrJobs,
      )..where((row) => row.id.isIn(staleIds))).write(
        OcrJobsCompanion(
          status: const Value('paused'),
          reason: const Value('interrupted'),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.ocrJobPages)..where(
            (row) =>
                row.jobId.isIn(staleIds) &
                (row.status.equals('rendering') |
                    row.status.equals('recognizing')),
          ))
          .write(
            OcrJobPagesCompanion(
              status: const Value('pending'),
              updatedAt: Value(now),
            ),
          );
    });
  }

  @override
  Future<void> deleteByBook(String bookId) async {
    final ids =
        await (_db.selectOnly(_db.ocrJobs)
              ..addColumns([_db.ocrJobs.id])
              ..where(_db.ocrJobs.bookId.equals(bookId)))
            .map((row) => row.read<String>(_db.ocrJobs.id) ?? '')
            .get();
    await _db.transaction(() async {
      if (ids.isNotEmpty) {
        await (_db.delete(
          _db.ocrJobPages,
        )..where((row) => row.jobId.isIn(ids))).go();
      }
      await (_db.delete(
        _db.ocrJobs,
      )..where((row) => row.bookId.equals(bookId))).go();
    });
  }

  OcrJob _mapJob(OcrJobRow row) {
    return OcrJob(
      id: row.id,
      taskId: row.taskId,
      bookId: row.bookId,
      sourceRevision: row.sourceRevision,
      config: OcrJobConfig.decode(row.configJson),
      status: OcrJobStatus.fromValue(row.status),
      reason: row.reason,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  OcrJobPage _mapPage(OcrJobPageRow row) {
    return OcrJobPage(
      id: row.id,
      jobId: row.jobId,
      pageNumber: row.pageNumber,
      status: OcrPageJobStatus.fromValue(row.status),
      attempt: row.attempt,
      ocrPageId: row.ocrPageId,
      expectedCacheSignature: row.expectedCacheSignature,
      errorCode: row.errorCode,
      updatedAt: row.updatedAt,
    );
  }
}

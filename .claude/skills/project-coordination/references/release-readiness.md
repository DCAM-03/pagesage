# Release Readiness

Do not infer release readiness from a historical pilot, an old smoke result, or a completed implementation task alone.

Build the release conclusion from:

1. active P0 and release-blocking items (`docs/release-checklist.md`, `docs/m4-release-checklist.md`,
   `docs/testing-ui-ux-checklist.md`);
2. constraints in `AGENTS.md` with pending or partial implementation, including the deferred list (MOBI/AZW, Calibre,
   cloud sync, accounts, DRM, OCR, bookstores, collaboration);
3. schema and data compatibility: migrations are forward-only, backup/restore works, and no release clears user data;
4. external gates such as signing keys, store accounts, device availability, and manual approval;
5. fresh runtime or end-to-end evidence for every required platform lane — at minimum Windows plus one Android target
   for platform changes;
6. explicit exclusions and deferred capabilities;
7. the reviewed source revision, explicit build inputs, artifact hash, and platform targets when a packaged artifact is
   in scope;
8. the named post-install smoke and a tested or executable rollback path for release changes.

Report each gate as `PASS`, `BLOCKED`, `EXCLUDED`, or `UNVERIFIED`, with its evidence source. A release is ready only
when every required gate is `PASS` and excluded items are explicitly accepted by the user.

Do not turn release readiness into release authorization. Tags, store uploads, signing changes, and remote operations
still require the user's explicit request.

Do not repair an artifact/configuration mismatch by mutating an unrelated database, credential record, or fallback
path. Stop at the failed gate and return the defect to its owning build or packaging task.

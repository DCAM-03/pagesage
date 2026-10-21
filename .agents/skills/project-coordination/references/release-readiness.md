# Release Readiness

Do not infer release readiness from a historical pilot, an old smoke result, or a completed implementation task alone.

Build the release conclusion from:

1. active P0 and release-blocking tasks;
2. accepted decisions with pending or partial implementation;
3. contract and migration compatibility requirements;
4. external gates such as credentials, providers, callbacks, DNS/TLS, or manual approval;
5. fresh runtime or end-to-end evidence for every required component lane;
6. explicit exclusions and deferred capabilities.
7. reviewed source revisions, explicit non-secret build inputs, artifact manifest/hash and deterministic scans when a
   deployable artifact is in scope;
8. pre-mutation backup, minimum authorized mutation scope, named post-change smoke, and a tested or executable rollback
   path for production changes.

Report each gate as `PASS`, `BLOCKED`, `EXCLUDED`, or `UNVERIFIED`, with its evidence source. A release is ready only when every required gate is `PASS` and excluded items are explicitly accepted by the decision owner.

Do not turn release readiness into deployment authorization. Production changes, tags, releases, and remote operations still require the user's explicit request.

Do not repair an artifact/configuration mismatch by mutating an unrelated backend, database, credential record, or
fallback path. Stop at the failed gate and return the defect to its owning build or deployment task.

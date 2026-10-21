# Runtime Smoke

Use runtime smoke to prove an already implemented path. Do not turn a smoke session into broad feature
implementation when it discovers a blocker.

## Prepare

1. Confirm the owning task, accepted prerequisite changes, target platform, sample books, and cleanup owner.
2. Discover the launch command, device target, database path, and any required external input from `AGENTS.md` and
   the task document.
3. Confirm no PageSage instance from an earlier run is still alive before launching, and record what you will kill at
   the end.
4. Define applicable lanes. Omit irrelevant lanes instead of manufacturing evidence.

Common PageSage lanes are static analysis, focused test, database and persistence, renderer (EPUB or PDF), app
desktop runtime, app Android runtime, and platform integration (file picker, secure storage, sharing, window
management).

## Run

- Run `flutter pub get`, `dart format .`, and `flutter analyze` before attributing a runtime failure to the change.
- Exercise the owning layer directly before blaming the UI: a PDF page-open failure is not a widget defect until the
  renderer path is proved.
- Exercise success, failure, and cleanup paths when they are part of the contract: corrupt file, encrypted PDF,
  deleted book file, restored backup, cancelled import.
- Run desktop (`flutter run -d windows` on Windows, or the Linux desktop target when that is the available host) and
  at least one Android target for platform changes.
- For reader work, follow the manual loop from `AGENTS.md`: open a real sample, navigate, receive location events,
  save progress, close, reopen at the same location.
- Keep API keys, selected book text, and full AI context out of task records, screenshots, logs, shell history, and
  temporary files. Confirm security storage behavior without printing the stored value.
- Remove disposable sample copies, temporary databases, and the running app process after the run.

Under a proxy-restricted network (this machine requires `http_proxy` for GitHub), record whether `flutter pub get`
relied on the proxy so a later run can reproduce the environment.

## Classify Lanes

Use one status per lane:

| Status | Meaning |
| --- | --- |
| `PASS` | The declared real runtime or end-to-end path passed. |
| `TOOLING_ONLY` | Only static, mock, fake, build, or isolated evidence ran. |
| `BLOCKED` | A required environment, device, sample, decision, service, or confirmed defect prevented the path. |
| `NOT_APPLICABLE` | The lane is outside the accepted task scope. |

Map the complete result back to `Validation Evidence`. Do not map a `TOOLING_ONLY` lane to `RUNTIME_PASS` or
`E2E_PASS`. A required `BLOCKED` lane keeps the overall claim blocked.

Report a matrix:

```text
Lane | Status | Evidence | Remaining risk / next action
<lane> | PASS/TOOLING_ONLY/BLOCKED/NOT_APPLICABLE | <command or flow> | <gap or none>
```

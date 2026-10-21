# Runtime Smoke

Use runtime smoke to prove an already implemented path. Do not turn a smoke session into broad feature implementation when it discovers a blocker.

## Prepare

1. Confirm the owning task, accepted prerequisite changes, target environment, and cleanup owner.
2. Discover health commands, service ports, startup procedures, test accounts, and external inputs from project instructions and manifests.
3. Start only the required services with the project's capability skill or documented launcher.
4. Define applicable lanes. Omit irrelevant lanes instead of manufacturing evidence.

Common lanes are infrastructure and health, raw protocol or API, backend runtime, generated client, SDK or package consumer, browser user flow, and external provider integration.

## Run

- Exercise raw protocol or API behavior before attributing an SDK failure to the server.
- Exercise success, authorization or validation denial, and cleanup paths when they are part of the contract.
- Run each changed SDK or consumer independently.
- For browser work, test the real authenticated or user-visible flow at applicable desktop and mobile viewports. Inspect failed requests, console errors, overflow, persistence, secrets, and logout or cleanup behavior when relevant.
- Use real backend payloads for strict write contracts. A typecheck, mock, or rendered page does not prove the write path.
- Keep secrets out of task records, screenshots, logs, shell history, and temporary files.
- Remove disposable resources and temporary credentials after the run.

## Classify Lanes

Use one status per lane:

| Status | Meaning |
| --- | --- |
| `PASS` | The declared real runtime or end-to-end path passed. |
| `TOOLING_ONLY` | Only static, mock, fake, build, or isolated evidence ran. |
| `BLOCKED` | A required environment, input, decision, service, or confirmed defect prevented the path. |
| `NOT_APPLICABLE` | The lane is outside the accepted task scope. |

Map the complete result back to `Validation Evidence`. Do not map a `TOOLING_ONLY` lane to `RUNTIME_PASS` or `E2E_PASS`. A required `BLOCKED` lane keeps the overall claim blocked.

Report a matrix:

```text
Lane | Status | Evidence | Remaining risk / next action
<lane> | PASS/TOOLING_ONLY/BLOCKED/NOT_APPLICABLE | <command or flow> | <gap or none>
```

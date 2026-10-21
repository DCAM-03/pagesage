# Acceptance Loop

## Serial Candidate Handoff

Execution owns code, focused tests, runtime preparation and execution evidence until it has stopped writing and
released the candidate. Acceptance may reserve a slot earlier, but it must not inspect or exercise a changing
worktree, fixture or service. The coordinator records the release only after observing the terminal execution result,
released paths and stopped background work; a written handoff or a healthy port is not a release.

Before any backend-dependent browser, integration or acceptance check, bind the running candidate to all of:

- repository, worktree/branch and actual HEAD or dirty source fingerprint;
- backend artifact/source fingerprint and OpenAPI or schema/migration fingerprint;
- runtime process/container identity, configuration source and fixed data-volume/fixture identity.

If the fingerprints do not match the required candidate, stop the check. Do not run the consumer matrix against an old
backend as a preliminary round and then repeat it after a rebuild. An old candidate may be used once for a named
causal diagnosis, explicitly marked diagnostic, never as acceptance evidence. Run the combined matching-candidate
browser matrix once and share its evidence across affected consumer reviews; replay only rows invalidated by a real
source, contract, fixture or runtime change.

## Acceptance Convergence

- Review a coherent user capability once. Split an intermediate review only for a named hard dependency or security
  boundary; helper, test and documentation edits are not separate acceptance stages.
- Before implementation, agree on observable completion criteria and decisive validation in the existing task.
  Execution implements and runs them; independent acceptance reviews the actual diff and checks whether the criteria
  cover affected behavior. Coordination checks ownership, candidate identity and records, without repeating that review.
- Independent review does not require independent re-execution of every green command. Apply the evidence reuse and
  risk-based replay rules in `validation-harness`; spend review effort on assertions and affected product behavior.
- Return one consolidated list. Each blocking finding names a violated accepted requirement or concrete defect,
  observed evidence, and the smallest repair/verification. Separate observed defects, material evidence gaps and optional
  improvements. A hypothetical edge case, preferred test style or extra coverage alone does not block delivery.
  Present useful optional improvements to the user with benefit and cost for their choice; do not silently discard
  them, implement them automatically or turn them into blocking requirements.
- Do not add requirements during re-acceptance. Newly discovered material security or correctness defects can block,
  with a concrete failure path; unrelated improvements stay outside this delivery's gate.
- Execution resolves the consolidated list before handing back. Re-accept only changed or invalidated rows and actual
  dependents, retaining other PASS results. Stop when the agreed scope is proved; no fresh round for record wording.
- Repeated incomplete handoffs require one harness/scope correction with the existing owners, not more chats, review
  layers, records or suites. Do not impose a round limit that would conceal an unresolved material defect.

## Acceptance Focus And Stop Rule

Review against the user's accepted outcome, rather than the volume of evidence or number of green commands:

1. Compare the actual diff with all accepted completion criteria, including promised behavior absent from the diff.
   Prioritize the main user journey and changed security/data boundaries; metadata and record polish come afterward.
2. Check the smallest runtime or E2E evidence that proves those criteria; reuse a valid prior result when its source,
   contract, fixture and entry point are unchanged.
3. Trace only changed contracts and their plausible consumers. Group unchanged entry points that share one static
   no-impact reason in a single matrix row, listing the grouped paths; do not perform a repository-wide inventory just
   to fill rows.
4. Select missing checks under `validation-harness`'s evidence decision; a changed row alone does not require replaying
   valid post-change execution evidence. A failed check needs a concrete failure classification and affected criterion.

For UI delivery, inspect the rendered main journey against the accepted interaction/design reference using
`validation-harness/references/frontend-structure.md`. Element presence, successful writes and builds alone cannot
establish visual or interaction fidelity.

When the task consumes a previously accepted backend, SDK or provider task, verify only the changed integration
boundary in this task and reuse the dependency's applicable evidence. Reopen the dependency's complete lifecycle or
account matrix only when its source/contract/fixture changed, a concrete integration regression was observed, or a
required boundary lacks valid proof. A shared runtime or similar feature name is not enough to expand acceptance.

Gather independent findings in one pass over the bounded scope. If one failure prevents dependent scenarios, mark
them blocked by that same finding and continue disjoint review; do not create a new defect per skipped test. Give
findings stable IDs, keep them on remediation, and recheck only their repairs and affected dependents. A newly blocking
finding on an unchanged path needs the missed requirement and concrete failure path, not just a new reviewer preference.

The review is complete when every blocking criterion is satisfied, every affected closure row is `VERIFIED` or
evidence-backed `NOT_AFFECTED`, and the required evidence depth is present. Do not open another turn for a timestamp,
record wording, a second identical screenshot, a second green result, or a phase label. Report optional improvements with
their benefit and cost after the gate instead of adding them to the acceptance loop.

## Acceptance Result

Acceptance is a separate, user-visible Codex task/thread. The coordination session dispatches and decides, but its own
review is not an acceptance session.

```text
Outcome: ACCEPTED | CHANGES_REQUIRED | BLOCKED
Acceptance session ID: <independent acceptance thread ID>
Originating execution session ID: <execution thread ID>
Acceptance session kind: independent Codex task/thread
Acceptance session scope: project-bound
Canonical project ID: <saved project ID>
Acceptance project ID: <same saved project ID>
Project binding verified: yes
Project catalog visibility verified: yes
Implementation State confirmed:
Validation Evidence confirmed:
Reviewed repositories / worktrees:
Scope and diff result:
Independent contract-closure result:
Runtime / E2E result:
Remaining risks:
Required follow-ups:
```

`ACCEPTED` requires every affected closure row to be verified or evidence-backed not affected and the decisive runtime or
E2E evidence for the task profile. Missing acceptance identity, mismatched or projectless binding, coordinator-only
review, static evidence, or a terminal execution summary cannot produce `ACCEPTED`. For a historical task whose implementation is already merged, the
originating execution thread may be unavailable only after catalog, archived-thread, task, branch, and commit
reconciliation; record `Originating execution session ID: unavailable (historical)` together with
`Historical acceptance exception: merged-commit-review-after-origin-unavailable`. If that historical review finds a
product defect, create a replacement execution task only with the recorded unavailability reason.

The independent acceptance task owns Phases 2-4 from `coordination-state-machine.md` in one stable acceptance slot.
Combine applicable Phase 2/3 work in one review; phase labels alone do not justify more turns or repeated tests.
It may report product `ACCEPTED` after focused acceptance passes and the derived impact regression passes or is
evidence-backed `NOT_APPLICABLE`. If commit/merge is authorized, coordination materializes the candidate commit and
asks the same slot to check Phase 4 candidate identity and merge readiness, without replaying unaffected product
checks. Otherwise record Phase 4 `NOT_APPLICABLE`. The acceptance task never merges or cleans worktrees.

## Remediation Result

For `CHANGES_REQUIRED`, preserve earlier records and append:

```text
Failed acceptance item:
Observed evidence:
Required outcome:
Affected closure rows:
Originating execution session:
Existing branch/worktree:
Next named harness:
```

Route the delta to the originating execution task/thread. A completed acceptance round receives no implementation
continuation. After remediation, reuse the same stable acceptance slot for a new review round unless it is demonstrably
unavailable or corrupted. For acceptance `BLOCKED`, coordination resolves the external or tooling gate before resuming
that acceptance slot.

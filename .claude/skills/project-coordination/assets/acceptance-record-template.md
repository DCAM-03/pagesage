### YYYY-MM-DD - <acceptance session or owner>

Reuse established identity and evidence links on continuation; record only the changed review boundary, findings,
replay rationale, and outcome. This template is not a requirement to copy every field into every remediation round.

- Acceptance session: `<independent acceptance session or subagent; never the coordination session and never the session that implemented the work>`
- Acceptance session ID:
- Originating execution session ID:
- Historical acceptance exception: `not applicable` | `merged-commit-review-after-origin-unavailable`
- Acceptance session kind: `delegated-subagent` | `separate-user-session` | `review-only`
- Acceptance session scope: `<same value; must not be same-session>`
- Parent coordination session:
- Canonical task (read-only during review):
- Owned acceptance evidence/record path:
- Released paths / stop-writing handoff:
- Execution release evidence: terminal execution result, stopped writers/background work, released paths, and candidate
  identity:
- Candidate bindings checked: source/HEAD fingerprint | database schema/migration fingerprint | renderer asset or
  sample-book identity | running app/device instance | configuration source
- Acceptance attempt:
- Accepted user outcomes / decisive completion criteria (link existing scope):
- Evidence reused and why still valid:
- Replayed checks and concrete reason for each replay:
- Outcome: ACCEPTED | CHANGES_REQUIRED | BLOCKED
- Phase 2 result / evidence: `2_INDEPENDENT_ACCEPTANCE -> PASS | FAIL | BLOCKED`
- Phase 3 result / evidence or N/A reason: `3_IMPACT_REGRESSION -> PASS | FAIL | BLOCKED | NOT_APPLICABLE`
- Phase 4 result / candidate commit / target-ref evidence: `4_MERGE_READINESS -> NOT_STARTED | PASS | FAIL | BLOCKED | NOT_APPLICABLE`
- Implementation State confirmed: DESIGN_ONLY | CONTRACT_ONLY | STUB_ONLY | IMPLEMENTED
- Validation Evidence confirmed: UNVERIFIED | TOOLING_PASS | RUNTIME_PASS | E2E_PASS | BLOCKED
- Evidence invalidated / task reopened: no | `<previous evidence; invalidation reason; exact rows reset to BLOCKED>`
- Quality audit: NOT_REQUIRED | NOT_RUN | NO_FINDINGS | REVIEWED | BLOCKED
- Reviewed repositories / worktrees:
- Product worktree cleanup eligibility: clean and removable | retained uncommitted work | not applicable
- App-managed detached worktree inventory / lifecycle state:
- Scope and diff review:
- Changed contracts independently derived from actual diff:
- Contract Closure Matrix: `<surface> -> VERIFIED | NOT_AFFECTED | BLOCKED: <direct evidence or concrete reason>`
- Official runtime / build / packaging entry points checked:
- Commands / flows independently checked:
- Conditional contract evidence checked: UI structure | migration/destructive data | renderer bridge | not applicable
- Dependency and contract reconciliation (no required `BLOCKED` closure row for acceptance):
- Evidence:
- Remaining risks:
- Optional improvements (benefit / cost; never an acceptance blocker):
- Blocking findings: `<stable ID; violated criterion; observed failure or material evidence gap; smallest repair/check>`
- Required follow-ups:
- Completion claim: NOT_COMPLETE | COMPLETE (`IMPLEMENTED + RUNTIME_PASS` or `IMPLEMENTED + E2E_PASS` only)
- Terminal route: `ACCEPTED -> close when Phase 4 is NOT_APPLICABLE, otherwise candidate commit then same acceptance slot Phase 4` | `CHANGES_REQUIRED -> originating execution` | `BLOCKED -> coordination gate`
- Canonical result / index write-back: pending coordination after terminal handoff (never complete from tooling-only evidence)

# Frontend Structural Validation

Use this reference when a task adds, moves, removes, or conditionally shows a field, control, card, section, tab,
menu, dialog, route entry, or repeated label.

## Freeze The Structure

Before implementation, record:

- exact route or page;
- owning surface and production component;
- target semantic container, card, section, tab, menu, or dialog;
- relative order when order is part of the behavior;
- responsive, permission, state, or feature-flag visibility conditions; and
- sibling or alternative containers that must not contain the control.

Do not infer placement from the first component that can render the content. Preserve API, state, inheritance,
validation, and mutation behavior unless the task explicitly changes them. A relocation must move the production
component; test-only placement or duplication is not implementation.

## Prove Ownership

Use scoped accessible queries or equivalent semantic boundaries for the changed placement. Select applicable checks;
do not add unrelated assertion categories to every UI change:

1. a positive assertion inside the declared target container;
2. a negative assertion that excluded sibling containers do not contain the control;
3. an order assertion when relative position is contractual;
4. preserved behavior and payload contract for any mutation path affected by the move; reuse applicable evidence; and
5. one bounded browser scenario when the user-visible claim or existing harness requires runtime rendering evidence.

Whole-page text presence, snapshot-only output, successful mutation responses, and global DOM scans do not prove
structural ownership.

## Compare The Delivered Experience

When the task promises design or interaction fidelity, identify the accepted reference and compare the actual rendered
page with it: hierarchy, grouping, spacing, typography, labels, controls and the main interaction. Review the relevant
role/scope and the states changed by the task, including success or failure feedback when applicable. Confirm that
an apparent design mismatch is not an intentional accepted change before reporting it.

Choose representative routes, states, languages and viewports by distinct behavior or layout; shared components do
not require the full cross-product of every route, locale and size. An affected translation, breakpoint, permission or
scope rule needs its own targeted check. Reuse applicable browser evidence; if no adequate evidence exists, run the
smallest real scenario that resolves the gap. Record visual divergence from the accepted design as a requirement
finding; personal taste beyond that reference is an optional improvement with benefit and cost.

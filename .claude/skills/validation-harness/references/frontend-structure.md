# Frontend Structural Validation

Use this reference when a task adds, moves, removes, or conditionally shows a field, control, card, section, tab,
menu, dialog, route entry, or repeated label.

PageSage has two distinct surfaces; freeze the structure against the correct one:

- desktop: dense operational layout, panels and sidebars, keyboard navigation;
- mobile: touch-first single column, toolbars that hide during reading, drawers for side panels.

## Freeze The Structure

Before implementation, record:

- exact route or page (`go_router` location) and reader surface;
- owning widget and production component;
- target semantic container, card, section, tab, menu, or dialog;
- relative order when order is part of the behavior;
- responsive, permission, state, or feature-flag visibility conditions — name the breakpoint explicitly; and
- sibling or alternative containers that must not contain the control, including the mobile variant of the same
  control when the change targets desktop only.

Do not infer placement from the first widget that can render the content. Preserve state, provider scope, validation,
and persistence behavior unless the task explicitly changes them. A relocation must move the production widget;
test-only placement or duplication is not implementation.

## Prove Ownership

Use scoped `Finder`s (`find.descendant(of: ...)`) or semantic boundaries for the changed placement. Select applicable
checks; do not add unrelated assertion categories to every UI change:

1. a positive assertion inside the declared target container;
2. a negative assertion that excluded sibling containers — and the other viewport's layout — do not contain the
   control;
3. an order assertion when relative position is contractual;
4. preserved behavior and persisted contract for any path affected by the move; reuse applicable evidence; and
5. one bounded real-app or golden scenario when the user-visible claim or existing harness requires rendering
   evidence.

Whole-page text presence (`find.text` anywhere), snapshot-only output, a successful write, and global finder scans do
not prove structural ownership.

## Compare The Delivered Experience

When the task promises design or interaction fidelity, identify the accepted reference — `docs/04-ui-design-system.md`,
`docs/03-interaction-spec.md`, `docs/09-design-system.md`, or a plan document — and compare the actual rendered screen
with it: hierarchy, grouping, spacing, typography, labels, controls, and the main interaction. Review the states
changed by the task, including success or failure feedback.

Check the constraints in `AGENTS.md`: no decorative gradients, gradient orbs, oversized rounded cards, nested cards, or
illustration-heavy layouts in core screens; icon-only buttons carry semantic labels and tooltips; contrast meets
WCAG AA; focus is visible; status is not conveyed by color alone.

Choose representative routes, states, languages, and viewports by distinct behavior or layout; shared widgets do not
require the full cross-product. An affected translation, breakpoint, or permission rule needs its own targeted check.
Reuse applicable evidence; if none exists, run the smallest real scenario that resolves the gap. Record visual
divergence from the accepted design as a requirement finding; personal taste beyond that reference is an optional
improvement with benefit and cost.

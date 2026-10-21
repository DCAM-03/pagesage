# Presentation Instructions

- Own routes, widgets, user interaction, reader presentation, and both desktop and mobile validation.
- Read `docs/03-interaction-spec.md`, `docs/04-ui-design-system.md`, and the task document before changing a flow or layout.
- Derive the focused analyze, test, and device/desktop validation commands from `AGENTS.md` and `pubspec.yaml`; record the commands actually used in the task execution record.
- Do not use bare `flutter test` or wildcard selectors as final acceptance.
- Use the `validation-harness` skill before non-trivial implementation; exercise the real reader flow and persisted state when those behaviors are claimed complete.
- Keep reader content primary. Toolbars hide during reading and never permanently cover text. Icon-only buttons need semantic labels and tooltips.
- Do not use decorative gradients, gradient orbs, oversized rounded cards, nested cards, or illustration-heavy layouts in core screens.
- Preserve WCAG AA contrast, visible focus, keyboard navigation on desktop, screen-reader labels, and non-color-only status.
- Escalate to the `project-coordination` skill when a renderer or locator contract is unresolved, or when cross-layer work requires dependency sequencing.

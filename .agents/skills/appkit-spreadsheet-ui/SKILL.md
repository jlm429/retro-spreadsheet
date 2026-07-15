---
name: appkit-spreadsheet-ui
description: Native AppKit spreadsheet interaction and rendering guidance. Read before changing MainWindow.mm, controllers, ribbon controls, formula bar, selection, scrolling, keyboard or mouse behavior, redraws, or AppKit tests.
---

# AppKit Spreadsheet UI

Use this skill with [AGENTS.md](../../../AGENTS.md). Read `spreadsheet-core`
for model mutations, `formula-engine` for formula behavior, and
`spreadsheet-testing` for local AppKit validation.

## Boundary and organization

- AppKit translates user actions into portable-core operations. It never owns
  workbook rules, formula evaluation, formatting semantics, or persistence.
- Keep document ownership, window/controller coordination, control setup,
  delegates, target/action, and rendering responsibilities explicit.
- Treat the ribbon, formula bar, table, row headers, scrolling, pasteboard,
  keyboard, mouse, and redraws as one interaction system rather than isolated
  callbacks.

## Interaction state

- Keep active cell, selected range, formula destination, formula reference,
  editing session, and first responder as distinct state. Do not infer one from
  another.
- `NSTableView` row selection is not the spreadsheet selection model. The
  controller-owned logical selection must survive table reloads and responder
  transitions.
- Render active-cell, rectangular-selection, and formula-reference state
  distinctly. Keep headers synchronized with table geometry and scrolling.
- Return commits formula-bar and cell editing through the explicit commit path.
  Escape cancels the formula draft. Loss of first responder alone never commits
  a formula.
- Formatting actions capture the logical selection and call formatting-only core
  APIs. They never pass through raw-value or formula-commit paths, replace cell
  contents, or silently cancel an edit.

## UI bug workflow

Before patching an AppKit bug, trace the callback, first-responder transition,
notification or delegate flow, logical selection, core mutation,
recalculation, redraw, and synchronization. Patch the first incorrect state
transition, not its visible symptom.

Prefer targeted cell configuration and redraws when they preserve editing and
selection state. Use full table reloads only when the model or visible values
actually require them, then restore synchronization explicitly.

Validate keyboard, mouse, accessibility, spacing, alignment, scrolling, and
rendering as part of correctness.

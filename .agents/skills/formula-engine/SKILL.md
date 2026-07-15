---
name: formula-engine
description: Formula parser, evaluator, references, aggregates, dependencies, and editing-session guidance. Read before changing formula syntax, calculation behavior, or formula-entry UI integration.
---

# Formula Engine

Use this skill with [AGENTS.md](../../../AGENTS.md) and
`spreadsheet-core`. Native event and responder behavior belongs in
`appkit-spreadsheet-ui`.

## Formula boundary

- Keep parsing, evaluation, reference parsing, ranges, error values, and
  recalculation independent of AppKit.
- The UI never evaluates formulas. It commits raw text through portable core
  APIs, then renders the resulting display value.
- Raw formula source and displayed value are distinct. Preserve the raw source
  in the formula bar and show the evaluated value in the grid.
- Keep `FormulaEditingSession` draft, destination, and temporary reference
  range separate from logical spreadsheet selection.

## Supported behavior

- Keep parser and evaluator responsibilities explicit and deterministic.
- Validate direct references, one-based spreadsheet names, ranges, aggregate
  arguments, whitespace handling, and malformed expressions at the formula
  boundary.
- Extend aggregate functions, reference syntax, or error behavior only with
  focused regression tests. Dropdowns expose only functions that are both
  implemented and tested.
- Maintain precise error behavior for invalid references, malformed formulas,
  numeric conversion failures, division by zero, and circular references.
- Register or refresh dependency behavior whenever a formula or precedent
  changes. Recalculation must update all affected displayed values.
- Circular references must terminate deterministically and render the defined
  cycle error, never recurse indefinitely.

## Completion rule

Formula work is incomplete until commit, evaluation, recalculation, dependency
behavior, rendering, and regression tests work together. For UI-driven formula
changes, also read `appkit-spreadsheet-ui` and trace the complete interaction.

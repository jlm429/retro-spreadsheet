---
name: spreadsheet-core
description: Portable C++ workbook model guidance. Read before changing workbook state, cells, formatting, undo/redo, persistence, CSV, recalculation, or other core spreadsheet semantics.
---

# Spreadsheet Core

Use this skill with [AGENTS.md](../../../AGENTS.md). Formula syntax and
evaluation rules live in `formula-engine`; test and CI rules live in
`spreadsheet-testing`.

## Ownership and boundaries

- Keep spreadsheet semantics in the portable C++ core. AppKit types and
  Objective-C++ must not enter core headers or sources.
- `Workbook` owns the fixed worksheet grid, raw cell contents, displayed
  values, portable formatting, dirty state, undo/redo history, persistence,
  recalculation, and revision state.
- `SelectionModel` and `FormulaEditingSession` are portable state models. They
  do not make a worksheet mutation by themselves.
- Keep values, formulas, formatting, selection, and editing state as separate
  concepts. Do not encode one as a side effect of another.
- Use explicit mutation APIs that report whether state changed. Do not hide
  mutations in getters, rendering paths, or convenience callbacks.

## Model invariants

- Validate cell and range boundaries at the model boundary. Range APIs may
  deliberately clamp only when their documented behavior requires it.
- Preserve raw formula text separately from evaluated display values.
- Formatting belongs to the workbook model, participates in undo/redo and dirty
  state, and never replaces raw contents or formulas.
- Recalculate deterministically after content mutations, loading, undo, and
  redo. Formatting-only mutations must not use value or formula commit paths.
- A whole-workbook clear removes raw contents and formatting, records one undo
  state only when something changed, recalculates, and updates dirty and
  revision state consistently.
- Undo and redo restore raw contents, formatting, dirty state, and derived
  values coherently. New mutations clear redo history.

## Persistence and lifetime

- CSV stores raw values and formulas only. Formatting is intentionally
  in-memory and must be reset when CSV is loaded.
- Keep CSV quoting, line endings, bounds, and file errors deterministic and
  covered by portable tests.
- The live `Workbook` is mutable and not thread-safe. It is currently owned by
  the document on the main thread.
- `Workbook::Snapshot` is a value type and `evaluateSnapshot()` is a pure
  calculation seam. Any future background result must be revision-checked on
  the main thread before it affects a live workbook.
- Encourage thread-ready value boundaries and explicit ownership without
  claiming thread safety or adding threads.

## Change checklist

1. Identify the invariant, mutation API, dirty-state effect, undo/redo effect,
   recalculation effect, and persistence boundary.
2. Keep model behavior deterministic and independently testable in C++.
3. Add focused regression tests for changed semantics, including no-op and
   boundary behavior where relevant.

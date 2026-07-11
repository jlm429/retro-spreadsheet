---
name: excel97-project
description: Use when developing the Retro Spreadsheet project, including planning, architecture, Qt Widgets implementation, formula evaluation, debugging, testing, and code review.
---

# Retro Spreadsheet Project

Follow **AGENTS.md** as the source of truth for workflow, Git behavior, verification, safety, and project scope.

This skill provides spreadsheet-specific engineering guidance.

---

## Project Vision

Build a polished educational spreadsheet application inspired by classic desktop spreadsheets.

Prioritize:

- incremental milestones
- working software after every change
- readable C++
- maintainable architecture
- Qt best practices
- focused automated tests

Avoid implementing broad feature sets in a single step.

---

## Architecture

Keep business logic independent from the user interface whenever practical.

Typical core components include:

- MainWindow
- SpreadsheetWidget
- SpreadsheetModel
- Workbook
- Worksheet
- Cell
- FormulaParser
- FormulaEvaluator
- FileManager
- UndoManager

Introduce additional systems only when justified by a concrete feature, such as:

- dependency graph
- clipboard manager
- selection model
- formatting engine

Favor simple designs that can evolve naturally.

---

## Feature Development

For significant features, explain:

- purpose
- affected files
- architectural impact
- tradeoffs
- verification strategy

Implement the smallest complete milestone before moving on.

---

## Formula System

Keep formula evaluation independent of Qt widgets.

Prefer:

- deterministic evaluation
- clear parser structure
- isolated model logic
- focused unit tests

Avoid coupling evaluation directly to UI behavior.

---

## User Interface

Maintain a polished desktop experience.

Evaluate:

- spacing
- alignment
- interaction flow
- keyboard behavior
- accessibility
- consistency with Qt Widgets conventions

Treat visual polish as part of correctness.

---

## Debugging

When builds or tests fail:

1. Read the complete error.
2. Identify the root cause.
3. Make the smallest reasonable correction.
4. Rebuild or rerun the failing test.
5. Avoid unrelated changes.

---

## Review Lens

When reviewing code, consider:

- maintainability
- readability
- Qt ownership
- signal-slot usage
- model/UI separation
- memory safety
- naming clarity
- unnecessary complexity
- test coverage

Ask:

> Is this simple enough to teach and solid enough to extend?

---

## Long-Term Direction

As the project grows, continue favoring:

- separation of concerns
- incremental development
- testable business logic
- reusable components
- educational clarity over clever implementations

Build a codebase that demonstrates modern C++ engineering practices while remaining approachable to students and contributors.
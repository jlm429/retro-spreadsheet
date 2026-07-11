---
name: excel97-project
description: Use when developing the Retro Spreadsheet project, including planning, architecture, Qt Widgets implementation, formula evaluation, debugging, refactoring, testing, and code review.
---

# Retro Spreadsheet Project Skill

Use this skill for hands-on work in the Retro Spreadsheet repository.

Follow `AGENTS.md` as the source of truth for workflow, safety, commits,
verification, and scope. This skill adds project-specific focus for spreadsheet
development.

## Project Focus

Build a polished educational C++17 and Qt 6 Widgets spreadsheet application
inspired by classic desktop spreadsheets.

Prioritize:

- incremental milestones
- working software after every change
- clear separation between UI and business logic
- readable C++ and Qt idioms
- focused tests for model, formula, file, and UI behavior

Avoid generating broad feature sets in one pass. Plan, implement, compile, test,
and then continue.

## Before Coding

- Inspect the current project structure and relevant `CMakeLists.txt` files.
- Read the affected source, headers, and tests.
- Identify the smallest useful milestone.
- Note compile blockers or architectural constraints.
- Define the verification command before making changes.

## Architecture Guide

Favor Model-View or MVC boundaries.

Core areas:

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

Introduce supporting systems only when needed by a concrete feature, such as a
dependency graph, clipboard manager, selection model, or formatting engine.

## Feature Work

For significant features, explain:

- purpose
- affected files
- architectural impact
- tradeoffs
- verification plan

Keep UI behavior precise and testable. For formula, persistence, and model logic,
prefer focused tests before or alongside implementation.

## Debugging

When compilation or tests fail:

1. Read the exact error output.
2. Identify the root cause.
3. Make the smallest reasonable correction.
4. Rebuild or rerun the failing test.

Do not regenerate unrelated code to fix local failures.

## Review Lens

Evaluate changes for:

- maintainability
- memory safety
- Qt ownership and signal-slot usage
- model and UI separation
- naming clarity
- test coverage
- unnecessary complexity

Ask whether the solution is simple enough to teach and strong enough to extend.

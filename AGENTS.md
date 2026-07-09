# AGENTS.md

## Project

Build a modern C++17 desktop spreadsheet application inspired by classic spreadsheet software (e.g., Excel 97). This is an educational software engineering project, not a feature-complete clone.

**Stack**
- C++17
- Qt 6 Widgets
- CMake
- CLion
- macOS

---

## Philosophy

Act as a senior software engineer and mentor.

Think before coding. Spend more time understanding the existing codebase than writing new code.

Always prefer:
- small, incremental improvements
- clean architecture
- readable, maintainable code
- working software after every change

Never generate large amounts of code when a smaller verified step will do.

---

## Workflow

Before making changes:

1. Inspect the current project.
2. Identify the next logical milestone.
3. Explain the plan if it significantly changes the design.
4. Implement only that milestone.
5. Build and test.
6. Fix any issues before continuing.
7. Add a concise entry to `CHANGELOG.md` for user-visible code, build, or
   documentation changes.

Never claim success without verification.

## Changelog

Track project changes in `CHANGELOG.md` as they are made.

Do not reorganize historical changelog entries or edit a changelog directory
unless the current task is specifically to add a new change entry there.

---

## Architecture

Favor separation of concerns.

Typical classes include:

- MainWindow
- SpreadsheetWidget
- SpreadsheetModel
- Workbook
- Worksheet
- Cell
- FormulaEvaluator
- FileManager

Keep business logic independent of the GUI whenever practical.

---

## Coding Style

Prefer:
- RAII
- smart pointers
- const correctness
- STL containers and algorithms
- Qt best practices
- descriptive names

Avoid:
- global state
- giant classes
- duplicated logic
- premature optimization
- unnecessary abstractions

Optimize for clarity over cleverness.

---

## Safety

Never expose, request, or hardcode secrets.

Always ask before:

- installing software or dependencies
- requesting API keys or credentials
- modifying system configuration
- deleting files
- rewriting git history
- force pushing
- making major architectural changes

Prefer proposing a plan before making significant changes.

When uncertain, ask.

---

## Collaboration

Treat the user as the lead developer.

Explain important design decisions.

Present reasonable alternatives when tradeoffs exist.

If a request is likely to introduce technical debt, explain why before implementing it.

---

## Scope

Implement only what was requested.

Do not add extra features or speculative improvements unless explicitly asked.

Finish the current milestone before moving to the next.

Leave the project in a better state after every change.

---

## Goal

Optimize for:

- maintainability
- software engineering best practices
- educational value
- clean architecture
- incremental development

# Agent Guidance

`AGENTS.md` is the canonical guidance for all coding assistants. Assistant-specific
files should link here instead of duplicating these rules.

## Project

Build a modern educational spreadsheet application inspired by classic desktop
spreadsheets, not a feature-complete clone.

Stack:

- C++17
- Qt 6 Widgets
- CMake
- CLion
- macOS

## Operating Principles

- Act as a senior engineer and mentor.
- Understand the existing code before changing it.
- Keep changes small, direct, reviewable, and working after each step.
- Prefer clean architecture, readable code, and maintainability over cleverness.
- Implement only what was requested. Do not add speculative features.
- State assumptions when they affect behavior, design, or scope.
- Push back when a request would add avoidable complexity or technical debt.
- Do not use em dashes in prose, code comments, docs, commit messages, or PR text.
- Do not add an agent name as a commit co-author.

## Workflow

Before changing code:

1. Check `git status`.
2. Read the relevant source files and tests.
3. Identify the next logical milestone.
4. Define how the change will be verified.
5. Explain the plan when it changes design or scope.

While changing code:

- Touch only files and lines needed for the task.
- Match the existing local style.
- Do not refactor or reformat unrelated code.
- Do not discard user changes.
- Remove only code made unused by the change.
- Mention unrelated defects separately instead of fixing them.
- For bug fixes, reproduce the issue end to end when feasible before fixing it.

After changing code:

1. Configure and build.
2. Run the automated tests.
3. Fix lint, build, test, or flaky failures when encountered.
4. Review `git diff`.
5. Confirm only intended files changed.
6. Report warnings, skipped tests, or unresolved issues.
7. Add a concise `CHANGELOG.md` entry for user-visible code, build, or
   documentation changes.

Never claim success without verification.

Standard local verification:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

Run configured formatting or static analysis before committing when available.

## Commits

Create a local Git commit only when explicitly requested.

Before committing:

- Run the relevant tests and confirm they pass.
- Review the staged diff.
- Ensure generated build files, secrets, credentials, and temporary files are not
  staged.
- Stage specific files, not `git add .`, unless repository status has been
  reviewed first.
- Use a concise commit message describing the completed change.

Do not push, force-push, amend, rebase, rewrite history, delete branches or tags,
modify remotes, or bypass failing tests unless explicitly instructed.

## Continuous Integration

Treat `.circleci/config.yml` as production configuration.

Before committing CircleCI changes:

- Validate the configuration when the CircleCI CLI is available.
- Run the corresponding local build and tests.
- Review the configuration diff.
- Do not add tokens, credentials, or other secrets.

Local success does not guarantee CircleCI success. Report local and remote results
separately. Inspect CircleCI only when access is available, and do not rerun,
cancel, approve, or modify remote pipelines unless explicitly requested.

## Changelog

Track project changes in `CHANGELOG.md` as they are made. Do not reorganize
historical entries unless the task specifically asks for changelog cleanup.

## Architecture

Favor separation of concerns and keep business logic independent of the GUI when
practical.

Common classes:

- MainWindow
- SpreadsheetWidget
- SpreadsheetModel
- Workbook
- Worksheet
- Cell
- FormulaEvaluator
- FileManager

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

## UI Quality

For UI changes, be exacting about interaction, layout, copy, spacing,
responsiveness, accessibility, and visual polish.

## Security

Never read, print, summarize, copy, commit, expose, request, or hardcode `.env`,
`.env.*`, API keys, tokens, credentials, or service account files. Document
required secrets only by variable name in `.env.example`.

Stop and alert the human reviewer if a secret is exposed.

Ask before:

- installing software or dependencies
- requesting API keys or credentials
- modifying system configuration
- deleting files
- rewriting Git history
- force pushing
- making major architectural changes

## Goal

Optimize for maintainability, educational value, clean architecture, and
incremental development.

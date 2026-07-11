# Agent Guidance

This document is the canonical guidance for all coding assistants working in this repository.

## Project

Build a modern educational spreadsheet application inspired by classic desktop spreadsheets.

Stack:

- C++17
- Qt 6 Widgets
- CMake
- CLion
- macOS

---

## Operating Principles

- Act as a senior engineer and mentor.
- Understand the existing code before making changes.
- Keep changes small, direct, reviewable, and working after each step.
- Prefer maintainability and readability over cleverness.
- Implement only what was requested.
- State assumptions when they affect behavior, design, or scope.
- Push back when a request would introduce unnecessary complexity or technical debt.
- Do not use em dashes in prose, comments, documentation, commit messages, or pull requests.
- Do not add an agent name as a commit co-author.

---

## Workflow

### Before changing code

- Check repository status.
- Read the relevant source files.
- Identify the next logical milestone.
- Define how the change will be verified.
- Explain the plan when it changes design or scope.

### While changing code

- Modify only the files required for the task.
- Match the existing coding style.
- Do not refactor unrelated code.
- Do not overwrite user changes.
- Remove only code made unnecessary by the requested change.
- Mention unrelated issues separately instead of fixing them.

### After changing code

- Configure and build.
- Run relevant automated tests.
- Resolve build or test failures introduced by the change.
- Review the final diff.
- Confirm only intended files changed.
- Report skipped tests, warnings, or remaining issues.
- Update CHANGELOG.md when user-visible code, build configuration, or documentation changes.
- Never claim success without verification.

Standard verification:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

---

## Git

Create local commits only when explicitly requested.

Before committing:

- Review the staged diff.
- Confirm generated files and secrets are not staged.
- Stage specific files whenever practical.
- Use concise commit messages.

Never perform the following unless explicitly requested:

- push
- force push
- rebase
- rewrite history
- delete branches or tags
- modify remotes

---

## Continuous Integration

Treat CI configuration as production infrastructure.

Before committing CI changes:

- Verify locally when practical.
- Review the configuration diff.
- Never commit secrets or credentials.
- Distinguish between local verification and remote CI results.

---

## Security

Never expose or commit:

- API keys
- tokens
- credentials
- `.env` files
- service account files

Document required secrets only by variable name in `.env.example`.

Stop and alert the user immediately if a secret appears to be exposed.

---

## Ask Before

Ask before:

- installing software
- requesting credentials
- modifying system configuration
- deleting files
- rewriting Git history
- force pushing
- making major architectural changes

---

## Goal

Optimize for:

- maintainability
- educational value
- clean architecture
- incremental software engineering
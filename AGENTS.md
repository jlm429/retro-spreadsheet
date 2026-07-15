# Agent Guidance

This is the canonical repository-wide guidance for coding agents. Read the
relevant skill before changing its subsystem.

## Project

Build a modern educational spreadsheet application inspired by classic desktop
spreadsheets.

Stack: C++17, CMake, and native macOS AppKit with Objective-C++ only at the UI
boundary. See [docs/project-structure.md](docs/project-structure.md) for the
current layout and component ownership.

## Architecture

The portable C++ core owns workbook state, formulas, formatting, parsing,
evaluation, recalculation, validation, persistence, and undo/redo.

The AppKit layer owns controls, rendering, mouse and keyboard input, selection
rendering, first responder management, and translation of user actions into
core operations.

- AppKit types never enter the portable core.
- Avoid global mutable state and keep data flow explicit.
- Do not introduce background threads unless requested.
- Never claim thread safety without synchronization.

## Skill routing

Read the applicable skill before changing code or tests in that area:

- Read `.agents/skills/spreadsheet-core/SKILL.md` before changing `Workbook`,
  worksheet state, cell formatting, persistence, undo/redo, or portable model
  behavior.
- Read `.agents/skills/formula-engine/SKILL.md` before changing formula syntax,
  parsing, evaluation, references, dependency behavior, or formula editing.
- Read `.agents/skills/appkit-spreadsheet-ui/SKILL.md` before changing AppKit
  controls, `MainWindow.mm`, interaction, rendering, selection, or native UI
  tests.
- Read `.agents/skills/spreadsheet-testing/SKILL.md` before adding, changing,
  or running tests, CTest configuration, or CircleCI configuration.

Read more than one skill when a change crosses boundaries. The skills contain
the detailed subsystem rules; do not duplicate them in prompts or unrelated
documentation.

## Operating principles

- Keep changes small, direct, reviewable, and working after each step.
- Prefer maintainability, readability, and root-cause fixes over cleverness.
- Implement only the requested scope. State assumptions that affect behavior,
  design, or scope.
- Do not overwrite user changes. Match the existing style.
- Preserve architectural boundaries and do not refactor unrelated code.
- Do not use em dashes in prose, comments, documentation, commit messages, or
  pull request text.

For substantial work, deliver one complete workflow rather than many partial
features. Establish architecture before breadth; complete model, UI, rendering,
tests, and documentation together. If the requested scope is too large, deliver
the architecture plus one complete vertical slice.

## Workflow

Before coding: inspect repository and worktree status, read affected code and
relevant skills, reproduce bugs when practical, trace affected event and data
flow, define verification first, and identify the smallest complete milestone.

During coding: preserve boundaries, keep builds working, avoid partially
implemented controls, and add regression tests with bug fixes whenever
practical. Resolve build or test failures introduced by the change.

After coding: run applicable portable tests and local AppKit tests for UI
changes, review the final diff and intended files, update `CHANGELOG.md` when
appropriate, and report skipped validation and remaining risks. Compilation
alone is never sufficient validation for UI behavior.

## Verification and testing

Use `CMakeLists.txt`, CTest registration, and `.circleci/config.yml` as the
authoritative commands and labels. Keep tests deterministic and bounded with
explicit timeouts for asynchronous or UI work. Maintain coverage for new or
changed behavior.

## Definition of done

A task is complete when the requested behavior is implemented, applicable
builds and tests pass, changed behavior has appropriate coverage, and relevant
documentation is updated. Never claim success without reporting verification.

## Git and CI safety

Create local commits only when explicitly requested. Before committing, review
the staged diff, exclude generated artifacts and secrets, stage focused files,
and use a concise commit message. Never add an agent name as a commit
co-author.

Do not push, force push, rebase, rewrite history, modify remotes, delete
branches, or delete tags unless explicitly requested.

Treat CI configuration as production infrastructure. Verify CI changes locally
when practical, review the configuration diff, and distinguish local validation
from remote CI results.

## Security

Never read, print, summarize, copy, commit, or expose API keys, access tokens,
credentials, service-account files, private certificates, or `.env` files.
Document secrets only by variable name in `.env.example`. Do not hardcode API
keys, tokens, authenticated endpoints, secrets, or personal filesystem paths.

If a secret appears exposed, stop immediately, notify the user, and do not
continue until it is addressed.

## Memory safety

Prefer RAII, automatic storage, standard-library containers, const correctness,
and `std::unique_ptr` or `std::shared_ptr` when ownership is shared. Avoid raw
owning pointers and manual `new` or `delete` unless justified. Keep ownership
explicit, document non-obvious lifetime relationships, minimize lifetimes, and
avoid dangling pointers, iterator invalidation, use-after-free, and undefined
behavior.

Changes affecting ownership, lifetime, or object relationships deserve extra
review.

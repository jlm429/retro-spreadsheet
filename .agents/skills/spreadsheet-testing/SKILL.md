---
name: spreadsheet-testing
description: Portable, local AppKit, CTest, and CircleCI validation guidance. Read before adding or changing tests, CMake test registration, CTest labels, test commands, or CI configuration.
---

# Spreadsheet Testing

Use this skill with [AGENTS.md](../../../AGENTS.md). Read the matching subsystem
skill to define behavior before selecting test coverage.

## Permanent test strategy

Portable tests are the Linux CI path. They must use C++ only, have no AppKit or
Objective-C++ dependency, remain deterministic and bounded, and focus on
regressions in core behavior.

Local AppKit tests are macOS-only. They exercise native controllers and must be
deterministic, bounded, cleanly shut down, and carry both `ui` and `local`
labels.

CircleCI runs portable tests only. It must exclude `ui` and `local`, never
launch AppKit, never install graphical dependencies, and never weaken tests to
satisfy CI.

## Current authoritative configuration

- `CMakeLists.txt` defines CTest registration, test labels, and per-test
  timeouts.
- `.circleci/config.yml` defines the Linux configure, build, and portable test
  workflow.
- `README.md` documents the current local commands and UI-test artifacts.

Keep these files aligned when test behavior changes. Do not copy commands into
new guidance unless they are sourced from these files.

## Change checklist

- Add a deterministic regression test for bug fixes whenever practical.
- Test portable behavior in the core suite. Test native interaction in the
  local AppKit suite when the bug depends on controllers or AppKit event flow.
- Set explicit, descriptive failure bounds for asynchronous or UI work.
- Run the applicable portable tests. Run local AppKit tests in an interactive
  macOS session after UI changes.
- A successful compile is not validation of UI behavior.

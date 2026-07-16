# Changelog

All notable project changes should be recorded here as they are made.

## Unreleased

- Fixed native worksheet Tab navigation to end the current shared field-editor
  session, move the logical selection once, and retain worksheet keyboard
  ownership. Repeated formula and value Tabs now keep the formula bar out of
  the responder path, preserve raw formulas, wrap correctly, and begin editing
  the destination only when the user types.
- Routed native grid and formula-bar Return, Tab, and Escape through one explicit
  commit or cancel path. Return retains the active cell, and Tab advances one
  column, wrapping from the final column to column A of the next row while the
  final worksheet cell remains active after its Tab commit. The local AppKit
  workflow now verifies immediate Center Alignment refresh without a follow-up
  edit.
- Added portable regression coverage for raw formula source, evaluated values,
  supported functions, dependent recalculation, undo, and redo.

- Reorganized coding-agent guidance into concise repository-wide rules and
  focused skills for spreadsheet core behavior, formulas, AppKit interaction,
  and testing.

- Fixed native cell selection to use controller-owned active-cell and rectangular
  range state instead of AppKit row highlighting. Added fixed synchronized
  one-based row headers and distinct formula-reference rendering.
- Fixed raw formula commits to refresh evaluated worksheet values while preserving
  formula-bar source text. Expanded portable formula coverage for comma arguments,
  whitespace, malformed formulas, blanks, text, ranges, recalculation, and cycles.
- Added local AppKit selection, row-header, and formula regression coverage. The
  `ui` and `local` tests remain excluded from CircleCI's portable Linux job.

- Fixed ribbon-click editing isolation: formatting captures the logical range,
  uses only portable formatting APIs, and refreshes visible cell formatting
  without reloading or committing an active grid or formula-bar editor.

- Fixed AppKit cell editing so a first-responder change cannot replace a raw
  formula with its displayed result. Ribbon formatting now applies only core
  formatting operations to the selected cell or rectangle.
- Fixed formula-bar Escape restoration while function/reference insertion remains
  in the draft until commit. Added native local smoke and bounded ribbon regression
  coverage for formatting, editing, references, recalculation, and undo/redo.
- Added explicit `ui` and `local` CTest labels. CircleCI continues to run only
  portable Linux tests and excludes both labels.

- Added portable cell formatting with undo/redo support, compact AppKit ribbon
  controls, and CSV style isolation so CSV files retain values and formulas only.
- Added raw-content formula editing with Return commit, Escape cancel, function
  templates for SUM, AVERAGE, MIN, MAX, and COUNT, plus cell and rectangular
  range reference insertion.
- Expanded the portable evaluator and Linux-safe test suite for MIN, MAX,
  COUNT, blank ranges, formatting persistence, and formula-entry state.

- Pinned the CircleCI Linux image to a version with CMake newer than the
  project's 3.21 minimum requirement.
- Moved CircleCI to a Linux executor that configures, builds, and tests only
  the portable C++ core. CMake now enables Objective-C++ and the AppKit bundle
  only for macOS application builds; the local UI smoke test is labeled `ui`
  and `local` and is not registered for portable builds.
- Stopped running the interactive AppKit smoke test on CircleCI's headless
  macOS executors. CI now excludes the `ui` CTest label, runs the bounded core
  suite with a 30-second outer timeout, and documents local UI smoke testing.
- Clarified the AppKit and C++ core boundary, removed an unused document
  operation queue and cancellation API, and added an immutable snapshot
  evaluation seam for future background calculation.
- Made core mutations report whether they changed workbook state so AppKit only
  marks a document dirty after a real edit. Added regression coverage for
  no-op and out-of-range mutations plus snapshot evaluation.
- Updated stale project and skill documentation left from the Qt migration.
- Made the UI smoke test launch the app bundle through Launch Services and
  require an explicit success marker from the application.
- Added CTest-based engine, CSV persistence, undo/redo, and AppKit smoke test
  coverage with bounded timeouts and UI failure diagnostics in CI.
- Added test-maintenance and Definition of Done requirements to the canonical
  repository guidance for future agent work.
- Fixed AppKit document registration and restored reliable active-cell editing,
  formula-bar updates, and clipboard commands in the spreadsheet grid.
- Retained test files as placeholders while removing test targets and CI test
  execution pending a new test suite.
- Migrated the application from Qt Widgets to native macOS AppKit with an
  `NSDocument`-owned portable C++17 workbook engine.
- Added native document lifecycle, CSV file dialogs and recent documents,
  dirty handling, formula bar editing, `NSTableView` spreadsheet editing, and
  range-aware clipboard commands.
- Removed Qt dependencies, replaced Qt tests with portable CTest coverage, and
  moved CircleCI builds to macOS.
- Added revision-tagged snapshots and cancellation tokens as explicit safe
  seams for future per-document serial background operations.
- Documented Linux build dependencies and refreshed README guidance summary.
- Added the CircleCI OpenGL development package required for Qt6Gui detection.
- Condensed and reorganized repository and skill guidance to remove duplicate
  instructions while preserving workflow, safety, and project-specific rules.
- Removed repository and skill workflow instructions for agent-run
  `no-mistakes` validation so pull request validation can be run manually.
- Added repository guidance for monitoring CircleCI on pull requests, and
  aligned the README technology list with the C++17 project standard.
- Added CircleCI build and test configuration plus repository workflow guidance
  for build, test, commit, and CI changes.
- Added agent-neutral behavioral safeguards to the repository guidance and
  pointed assistant-specific guidance back to `AGENTS.md`.
- Reorganized headers under `include/RetroSpreadsheet/` and added project
  structure docs plus resource directories for future icons and themes.
- Refactored UI action setup and formula aggregation internals for easier
  maintenance.
- Added Qt Test regression coverage for formulas, CSV persistence, dirty state,
  cell range references, and clipboard operations.
- Added dirty workbook tracking, save prompts, recent CSV files, and current
  file names in the window title.
- Expanded formulas with direct cell references, multiplication, division, and
  `AVERAGE(...)` ranges.
- Added Edit menu and toolbar commands for copy, cut, and paste across selected
  cell ranges.
- Added an `fx` formula bar and Formula menu commands for inserting `SUM` and
  `AVERAGE` formulas from selected cell ranges.
- Added initial Qt 6 Widgets retro spreadsheet prototype with CMake, CSV
  import/export, editable cells, and simple `=A1+B1` or `=A1-B1` formula
  evaluation.
- Added repository guidance to keep future user-visible code, build, and
  documentation changes recorded in this changelog.
- Aligned project guidance and skill guidance with the C++17 target.
- Added `SUM(...)` formulas with support for cell ranges such as
  `=SUM(A1:A10)` and comma-separated references such as `=SUM(A1,B1)`.

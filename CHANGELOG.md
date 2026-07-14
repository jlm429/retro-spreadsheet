# Changelog

All notable project changes should be recorded here as they are made.

## Unreleased

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

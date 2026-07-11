# Changelog

All notable project changes should be recorded here as they are made.

## Unreleased

- Added repository guidance for running `no-mistakes` validation and monitoring
  CircleCI on pull requests, and aligned the README technology list with the
  C++17 project standard.
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
- Added a macOS GitHub Actions CI workflow that builds the app and runs `ctest`.
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

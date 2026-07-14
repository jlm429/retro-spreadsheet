# Project Structure

This project uses a conventional C++ desktop application layout.

- `.circleci/config.yml`: unattended Linux configure, portable-core build, and labeled core-test workflow. See the README test section for local UI smoke-test availability.
- `CMakeLists.txt`: portable CMake core and tests, with an optional macOS AppKit bundle target.
- `include/RetroSpreadsheet/`: public headers for app components.
- `src/`: implementation files and the application entry point.
- `resources/`: bundle metadata plus placeholders for future icons and native theme assets.
- `tests/`: dependency-free C++ core tests. On local macOS AppKit builds, CTest also registers a bounded UI smoke test.
- `skills/`: project-specific agent guidance.

The core target contains `Workbook`, `FormulaEvaluator`, and
`FormulaEditingSession`. `Workbook` owns the fixed 20 by 10 grid, raw values,
portable cell formatting, CSV persistence, undo history, dirty state, and
recalculation. CSV deliberately contains raw values and formulas only.
`FormulaEvaluator` and `FormulaEditingSession` have no UI dependency;
`FormulaEditingSession` keeps an uncommitted destination, draft, and temporary
reference range separate from native selection rendering. `Workbook` is mutable
and main-thread-owned by the current document; it is not safe for concurrent
access. `Workbook::Snapshot` is a value type and
`Workbook::evaluateSnapshot()` is a UI-independent calculation seam for future
background operations. A result must be revision-checked by the main thread
before it is applied to a live workbook.

`MainWindow.mm` is the Objective-C++ boundary. `WorkbookDocument` owns the C++
workbook and maps CSV errors to `NSError`. `SpreadsheetWindowController` owns
window construction, active-cell selection, rendering, pasteboard access, and
translation of UI actions into `Workbook` operations. No AppKit type is exposed
to the core target.

Keep new business logic separate from UI code. Put workbook behavior and
validation in the core with focused C++ tests; keep native controls, menus,
dialogs, selection, and rendering in AppKit.

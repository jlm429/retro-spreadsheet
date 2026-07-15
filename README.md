# Retro Spreadsheet

A modern C++ desktop spreadsheet inspired by classic applications like Excel 97.

This repository explores **Agentic Software Engineering**: using modern AI coding agents to collaboratively design, build, test, and evolve a real software project over time.

---

## Project Goals

The spreadsheet serves as a realistic application for exploring:

- Object-oriented design
- native macOS desktop development
- File I/O
- Formula evaluation
- Dependency graphs
- Parsing and expression evaluation
- Testing
- Refactoring
- Incremental software engineering

---

## Repository Organization

```
AGENTS.md                  Repository-wide engineering principles
CMakeLists.txt             CMake build and app targets
include/RetroSpreadsheet/  Public headers for app components
src/                       Application source code
tests/                     Fast C++ engine tests and UI smoke-test support
docs/                      Project documentation
resources/                 Placeholder directories for future assets
.agents/skills/            Focused project skills
```

### AGENTS.md

Defines the engineering principles that guide every change in the repository, including:

- coding philosophy
- architectural guidelines
- safety rules
- workflow, commit, CI, and changelog expectations

### Skills

Skills provide specialized domain knowledge that is loaded only when relevant.

The repository provides focused skills for spreadsheet core behavior, formula
engineering, AppKit interaction, and testing. `AGENTS.md` states exactly when
each one must be read.

Keeping repository guidance separate from specialized skills helps minimize context while allowing deeper expertise when needed.

---

## Current Prototype

The application is a native macOS AppKit spreadsheet with:

- a 20 row by 10 column worksheet
- native `NSDocument` open, save, save as, recent document, and dirty handling
- a compact classic ribbon for font family, size, bold, italic, underline, and horizontal alignment, applied to the active cell or a Shift-click-selected rectangular range without replacing cell contents, committing an active cell or formula-bar edit, or changing the logical selection
- editable `NSTableView` cells plus a raw-content `fx` formula bar where Return commits without moving the active cell, Tab commits and advances one column, wrapping from the final column to column A of the next row, while Tab at the final worksheet cell retains that active cell, and Escape restores the original raw content
- copy, cut, and paste for rectangular cell ranges
- formulas using direct references, `+`, `-`, `*`, `/`, `SUM(...)`,
  `AVERAGE(...)`, `MIN(...)`, `MAX(...)`, and `COUNT(...)`

Formula cells display their evaluated value in the grid while the `fx` bar
retains the raw formula source for the active cell. Formula references use
spreadsheet-style names such as `A1`. `SUM`,
`AVERAGE`, `MIN`, `MAX`, and `COUNT` accept single cells, ranges such as
`A1:B3`, and comma-separated arguments such as `A1,B1`. The function dropdown
starts an uncommitted formula template; while editing, clicking or dragging the
grid inserts one cell or rectangular range reference without changing the
destination cell. Formatting is in-memory workbook state and is intentionally
not stored in CSV files.

---

## Technology

- C++17
- AppKit and Objective-C++ at the UI boundary
- CMake
- Xcode or CLion
- Git

## Build

The portable core builds on macOS and Linux with a C++17 compiler and CMake:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
```

On macOS, this also builds the native AppKit application. Linux configures and
builds only the portable core and its tests. To build only the core locally on
macOS, add `-DRETRO_SPREADSHEET_BUILD_APP=OFF` to the configure command.

## Tests

CTest runs the dependency-free C++ engine suite and, on macOS when the AppKit
application is enabled, registers separate local AppKit smoke and selection/formula
regression tests. The engine suite is the default fast-feedback path and does not launch a
GUI or access the network. CircleCI uses a Linux executor and configures only
the portable core. It explicitly excludes both `ui` and `local` labels.

```sh
# Portable tests, including unit and integration coverage. This is the CI path.
ctest --test-dir build --output-on-failure --label-exclude 'ui|local' --timeout 15

# AppKit smoke test. Run locally in an interactive macOS session.
ctest --test-dir build --output-on-failure -R RetroSpreadsheetUiSmoke --timeout 15

# AppKit selection, row-header, and formula regression test. Run locally in an interactive macOS session.
ctest --test-dir build --output-on-failure -R RetroSpreadsheetUiSelectionFormulaRegression --timeout 20

# All local tests, including portable and AppKit coverage.
ctest --test-dir build --output-on-failure --timeout 20
```

Every CTest process has an explicit timeout. Core tests have a 5-second limit,
the local smoke test has a 10-second limit, and the local selection/formula regression test has a
15-second limit. The app launcher itself has a 12-second limit. CI additionally
applies CTest's 15-second timeout and a 30-second process timeout, so a child
process that does not terminate cannot hold the job indefinitely. The local UI
tests launch the app bundle through Launch Services, wait at most 5 seconds for
the window and grid, and capture diagnostics in `build/ui-test-artifacts` or
`build/ui-e2e-test-artifacts` on failure. A `success.txt` marker prevents a
launcher failure from being reported as a passing UI test.

For future expansion, use GoogleTest when a vendored C++ assertion framework
is desired, and XCTest for richer AppKit interaction tests. The current CTest
runner intentionally has no downloaded dependency, which keeps local and CI
feedback deterministic and unattended.

The portable C++17 engine stays synchronous for the current 20×10 workbook.
`Workbook` itself is mutable and is not thread-safe. Future expensive work
must take a `Workbook::Snapshot` on the main thread, call the pure
`Workbook::evaluateSnapshot()` API away from AppKit, then return to the main
thread and compare the result revision before applying it. AppKit controllers,
`NSDocument`, and all access to the live `Workbook` remain on the main thread.

The grid has one active cell and controller-owned rectangular selection. AppKit
row selection is disabled: the grid renders the active cell and selected range,
while formula-reference ranges use a distinct orange highlight. Fixed one-based
row headers scroll vertically with the worksheet and remain fixed horizontally.
Click a cell to make it active, then Shift-click another cell or drag from the
active cell to select a rectangular range for ribbon formatting, copy, cut, and
clear operations; paste begins at the active cell.

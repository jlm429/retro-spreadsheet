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
CMakeLists.txt             CMake build, app, and CTest targets
include/RetroSpreadsheet/  Public headers for app components
src/                       Application source code
tests/                     Qt Test regression suites
docs/                      Project documentation
resources/                 Placeholder directories for future assets
skills/                    Specialized engineering knowledge
```

### AGENTS.md

Defines the engineering principles that guide every change in the repository, including:

- coding philosophy
- architectural guidelines
- safety rules
- workflow, commit, CI, and changelog expectations

### Skills

Skills provide specialized domain knowledge that is loaded only when relevant.

Examples include:

- spreadsheet engineering
- formula evaluation
- dependency graphs
- AppKit development

Keeping repository guidance separate from specialized skills helps minimize context while allowing deeper expertise when needed.

---

## Current Prototype

The application is a native macOS AppKit spreadsheet with:

- a 20 row by 10 column worksheet
- native `NSDocument` open, save, save as, recent document, and dirty handling
- editable `NSTableView` cells plus an `fx` formula bar
- copy, cut, and paste for rectangular cell ranges
- formulas using direct references, `+`, `-`, `*`, `/`, `SUM(...)`, and
  `AVERAGE(...)`

Formula references use spreadsheet-style names such as `A1`. `SUM` and
`AVERAGE` accept single cells, ranges such as `A1:B3`, and comma-separated
arguments such as `A1,B1`.

---

## Technology

- C++17
- AppKit and Objective-C++ at the UI boundary
- CMake
- Xcode or CLion
- Git

## Build and test

This project builds on macOS with Xcode command-line tools and CMake:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

The portable C++17 engine stays synchronous for the current 20×10 workbook.
It exposes immutable revision-tagged snapshots, per-document serial operation
queues, cancellation tokens, and main-thread revision checks as safe seams for
future background operations. AppKit controllers and all live workbook access
remain on the main thread.

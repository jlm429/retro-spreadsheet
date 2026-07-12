# Retro Spreadsheet

A modern C++ desktop spreadsheet inspired by classic applications like Excel 97.

This repository explores **Agentic Software Engineering**: using modern AI coding agents to collaboratively design, build, test, and evolve a real software project over time.

---

## Project Goals

The spreadsheet serves as a realistic application for exploring:

- Object-oriented design
- Qt desktop development
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
CMakeLists.txt             CMake build, app, and Qt Test targets
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
- Qt development

Keeping repository guidance separate from specialized skills helps minimize context while allowing deeper expertise when needed.

---

## Current Prototype

The application is a Qt Widgets spreadsheet prototype with:

- a 20 row by 10 column worksheet
- CSV open, save, save as, and recent file actions
- dirty workbook tracking with save prompts
- editable cells plus an `fx` formula bar
- copy, cut, and paste for contiguous cell ranges
- formulas using direct references, `+`, `-`, `*`, `/`, `SUM(...)`, and
  `AVERAGE(...)`

Formula references use spreadsheet-style names such as `A1`. `SUM` and
`AVERAGE` accept single cells, ranges such as `A1:B3`, and comma-separated
arguments such as `A1,B1`.

---

## Technology

- C++17
- Qt 6 Widgets
- CMake
- CLion
- Git

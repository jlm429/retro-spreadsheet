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
AGENTS.md        Repository-wide engineering principles
ROADMAP.md       Project roadmap and milestones
skills/          Specialized engineering knowledge
src/             Application source code
```

### AGENTS.md

Defines the engineering principles that guide every change in the repository, including:

- coding philosophy
- architectural guidelines
- safety rules
- collaboration practices

### Skills

Skills provide specialized domain knowledge that is loaded only when relevant.

Examples include:

- spreadsheet engineering
- formula evaluation
- dependency graphs
- Qt development

Keeping repository guidance separate from specialized skills helps minimize context while allowing deeper expertise when needed.

---

## Development Philosophy

Every change should:

- leave the application in a working state
- be small, incremental, and verifiable
- improve maintainability
- be understandable by future developers

The goal is to practice software engineering - not simply generate code.

---

## Technology

- C++17
- Qt 6 Widgets
- CMake
- CLion
- Git

# Project Structure

This project uses a conventional C++ desktop application layout.

- `.circleci/config.yml`: Linux CI build and `ctest` workflow.
- `CMakeLists.txt`: CMake project, application target, core library, and tests.
- `include/RetroSpreadsheet/`: public headers for app components.
- `src/`: implementation files and the application entry point.
- `resources/icons/`: future application icons and toolbar artwork.
- `resources/themes/`: future Qt stylesheets or theme assets.
- `tests/`: Qt Test regression suites runnable through `ctest`.
- `skills/`: project-specific agent guidance.

The core target contains the main window, spreadsheet controller, and formula
evaluator. The controller owns the fixed 20 by 10 grid, CSV persistence,
clipboard operations, dirty state, and recalculation. The evaluator keeps
formula behavior independent from the GUI.

Keep new business logic separate from UI code where practical. Prefer adding Qt
Test coverage for formula, file, and controller behavior before expanding the
GUI.

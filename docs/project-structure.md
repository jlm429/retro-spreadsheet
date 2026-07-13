# Project Structure

This project uses a conventional C++ desktop application layout.

- `.circleci/config.yml`: macOS CI build workflow.
- `CMakeLists.txt`: CMake project, AppKit bundle target, and core library.
- `include/RetroSpreadsheet/`: public headers for app components.
- `src/`: implementation files and the application entry point.
- `resources/icons/`: future application icons and toolbar artwork.
- `resources/themes/`: future native theme assets.
- `tests/`: retained placeholders for a future test suite, not built or run.
- `skills/`: project-specific agent guidance.

The core target contains `Workbook` and `FormulaEvaluator`. `Workbook` owns the
fixed 20 by 10 grid, CSV persistence, dirty state, and recalculation. The
AppKit window owns selection and pasteboard operations, native dialogs, and
menus. Formula behavior remains independent from the GUI.

Keep new business logic separate from UI code where practical. A new test suite
will be added before further GUI expansion.

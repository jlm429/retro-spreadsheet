# Project Structure

This project uses a conventional C++ desktop application layout.

- `include/RetroSpreadsheet/`: public headers for app components.
- `src/`: implementation files and the application entry point.
- `resources/icons/`: future application icons and toolbar artwork.
- `resources/themes/`: future Qt stylesheets or theme assets.
- `tests/`: Qt Test regression suites runnable through `ctest`.
- `skills/`: project-specific agent guidance.

Keep new business logic separate from UI code where practical. Prefer adding
tests for formula, file, and controller behavior before expanding the GUI.

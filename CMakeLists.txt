cmake_minimum_required(VERSION 3.21)

project(RetroSpreadsheet VERSION 0.2.0 LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(RetroSpreadsheetCore STATIC
    src/FormulaEvaluator.cpp
    src/FormulaEditingSession.cpp
    src/SelectionModel.cpp
    src/Workbook.cpp
    include/RetroSpreadsheet/FormulaEditingSession.h
    include/RetroSpreadsheet/FormulaEvaluator.h
    include/RetroSpreadsheet/SelectionModel.h
    include/RetroSpreadsheet/Workbook.h
)
target_include_directories(RetroSpreadsheetCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_options(RetroSpreadsheetCore PRIVATE -Wall -Wextra -Wpedantic)

option(RETRO_SPREADSHEET_BUILD_APP "Build the native macOS AppKit application" ${APPLE})

if(RETRO_SPREADSHEET_BUILD_APP)
    if(NOT APPLE)
        message(FATAL_ERROR "RETRO_SPREADSHEET_BUILD_APP requires macOS and AppKit.")
    endif()

    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 17)
    set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

    add_executable(RetroSpreadsheet MACOSX_BUNDLE
        src/main.cpp
        src/AppKitTheme.h
        src/AppKitTheme.mm
        src/MainWindow.mm
        include/RetroSpreadsheet/MainWindow.h
        resources/Info.plist
    )
    target_link_libraries(RetroSpreadsheet PRIVATE RetroSpreadsheetCore "-framework AppKit")
    target_compile_options(RetroSpreadsheet PRIVATE -Wall -Wextra -Wpedantic -fobjc-arc)
    set_target_properties(RetroSpreadsheet PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER com.jlm429.retrospreadsheet
        MACOSX_BUNDLE_BUNDLE_NAME "Retro Spreadsheet"
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/resources/Info.plist
    )
endif()

if(BUILD_TESTING)
    add_executable(RetroSpreadsheetCoreTests
        tests/FormulaEvaluatorTests.cpp
        tests/FormulaEditingSessionTests.cpp
        tests/WorkbookTests.cpp
    )
    target_link_libraries(RetroSpreadsheetCoreTests PRIVATE RetroSpreadsheetCore)
    target_compile_options(RetroSpreadsheetCoreTests PRIVATE -Wall -Wextra -Wpedantic)
    add_test(NAME RetroSpreadsheetCoreTests COMMAND RetroSpreadsheetCoreTests)
    set_tests_properties(RetroSpreadsheetCoreTests PROPERTIES TIMEOUT 5 LABELS "unit;integration")

    if(RETRO_SPREADSHEET_BUILD_APP)
        add_test(NAME RetroSpreadsheetUiSmoke
            COMMAND ${CMAKE_COMMAND}
                -DRETRO_SPREADSHEET_APP=$<TARGET_BUNDLE_DIR:RetroSpreadsheet>
                -DRETRO_SPREADSHEET_UI_ARTIFACTS=${CMAKE_BINARY_DIR}/ui-test-artifacts
                -DRETRO_SPREADSHEET_UI_ARGUMENT=--ui-smoke-test
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunUiSmoke.cmake)
        set_tests_properties(RetroSpreadsheetUiSmoke PROPERTIES
            TIMEOUT 10
            LABELS "ui;local"
            RUN_SERIAL TRUE
            ENVIRONMENT "RETRO_SPREADSHEET_UI_ARTIFACTS=${CMAKE_BINARY_DIR}/ui-test-artifacts"
        )
        add_test(NAME RetroSpreadsheetUiSelectionFormulaRegression
            COMMAND ${CMAKE_COMMAND}
                -DRETRO_SPREADSHEET_APP=$<TARGET_BUNDLE_DIR:RetroSpreadsheet>
                -DRETRO_SPREADSHEET_UI_ARTIFACTS=${CMAKE_BINARY_DIR}/ui-e2e-test-artifacts
                -DRETRO_SPREADSHEET_UI_ARGUMENT=--ui-e2e-test
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunUiSmoke.cmake)
        set_tests_properties(RetroSpreadsheetUiSelectionFormulaRegression PROPERTIES
            TIMEOUT 15
            LABELS "ui;local;integration"
            RUN_SERIAL TRUE
            ENVIRONMENT "RETRO_SPREADSHEET_UI_ARTIFACTS=${CMAKE_BINARY_DIR}/ui-e2e-test-artifacts"
        )
    endif()
endif()

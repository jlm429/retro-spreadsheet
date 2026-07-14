cmake_minimum_required(VERSION 3.21)

project(RetroSpreadsheet VERSION 0.2.0 LANGUAGES CXX OBJCXX)

include(CTest)

if(NOT APPLE)
    message(FATAL_ERROR "Retro Spreadsheet is a native macOS AppKit application and must be built on macOS.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

add_library(RetroSpreadsheetCore STATIC
    src/FormulaEvaluator.cpp
    src/Workbook.cpp
    include/RetroSpreadsheet/FormulaEvaluator.h
    include/RetroSpreadsheet/Workbook.h
)
target_include_directories(RetroSpreadsheetCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_options(RetroSpreadsheetCore PRIVATE -Wall -Wextra -Wpedantic)

add_executable(RetroSpreadsheet MACOSX_BUNDLE
    src/main.cpp
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

if(BUILD_TESTING)
    add_executable(RetroSpreadsheetCoreTests
        tests/FormulaEvaluatorTests.cpp
        tests/WorkbookTests.cpp
    )
    target_link_libraries(RetroSpreadsheetCoreTests PRIVATE RetroSpreadsheetCore)
    target_compile_options(RetroSpreadsheetCoreTests PRIVATE -Wall -Wextra -Wpedantic)
    add_test(NAME RetroSpreadsheetCoreTests COMMAND RetroSpreadsheetCoreTests)
    set_tests_properties(RetroSpreadsheetCoreTests PROPERTIES TIMEOUT 5 LABELS "unit;integration")

    add_test(NAME RetroSpreadsheetUiSmoke
        COMMAND ${CMAKE_COMMAND}
            -DRETRO_SPREADSHEET_APP=$<TARGET_BUNDLE_DIR:RetroSpreadsheet>
            -DRETRO_SPREADSHEET_UI_ARTIFACTS=${CMAKE_BINARY_DIR}/ui-test-artifacts
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunUiSmoke.cmake)
    set_tests_properties(RetroSpreadsheetUiSmoke PROPERTIES
        TIMEOUT 10
        LABELS "ui"
        RUN_SERIAL TRUE
        ENVIRONMENT "RETRO_SPREADSHEET_UI_ARTIFACTS=${CMAKE_BINARY_DIR}/ui-test-artifacts"
    )
endif()

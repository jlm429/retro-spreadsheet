cmake_minimum_required(VERSION 3.21)

project(RetroSpreadsheet VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Test Widgets)

enable_testing()

add_library(RetroSpreadsheetCore STATIC
    src/FormulaEvaluator.cpp
    include/RetroSpreadsheet/FormulaEvaluator.h
    src/MainWindow.cpp
    include/RetroSpreadsheet/MainWindow.h
    src/SpreadsheetController.cpp
    include/RetroSpreadsheet/SpreadsheetController.h
)

target_link_libraries(RetroSpreadsheetCore PUBLIC Qt6::Widgets)
target_include_directories(RetroSpreadsheetCore PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

qt_add_executable(RetroSpreadsheet
    MACOSX_BUNDLE
    src/main.cpp
)

target_link_libraries(RetroSpreadsheet PRIVATE RetroSpreadsheetCore)

add_executable(FormulaEvaluatorTests
    tests/FormulaEvaluatorTests.cpp
)

target_link_libraries(FormulaEvaluatorTests PRIVATE RetroSpreadsheetCore Qt6::Test)

add_test(NAME FormulaEvaluatorTests COMMAND FormulaEvaluatorTests)

add_executable(SpreadsheetControllerTests
    tests/SpreadsheetControllerTests.cpp
)

target_link_libraries(SpreadsheetControllerTests PRIVATE RetroSpreadsheetCore Qt6::Test)

add_test(NAME SpreadsheetControllerTests COMMAND SpreadsheetControllerTests)
set_tests_properties(SpreadsheetControllerTests PROPERTIES
    ENVIRONMENT QT_QPA_PLATFORM=offscreen
)

set_target_properties(RetroSpreadsheet PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.retrospreadsheet
    MACOSX_BUNDLE_BUNDLE_NAME "Retro Spreadsheet"
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
)

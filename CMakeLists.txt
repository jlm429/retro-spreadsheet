cmake_minimum_required(VERSION 3.21)

project(RetroSpreadsheet VERSION 0.2.0 LANGUAGES CXX OBJCXX)

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
set_target_properties(RetroSpreadsheet PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER com.jlm429.retrospreadsheet
    MACOSX_BUNDLE_BUNDLE_NAME "Retro Spreadsheet"
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/resources/Info.plist
)

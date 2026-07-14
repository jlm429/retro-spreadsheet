#pragma once

// Creates the native AppKit application. AppKit implementation remains in the
// Objective-C++ boundary; the workbook engine is portable C++.
int runRetroSpreadsheetApplication(int argc, const char *argv[]);

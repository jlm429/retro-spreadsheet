#include "RetroSpreadsheet/Workbook.h"

#include <cstdlib>
#include <filesystem>
#include <iostream>

namespace {
void expect(const std::string &actual, const std::string &expected, const char *description)
{
    if (actual == expected) return;
    std::cerr << description << ": expected " << expected << ", got " << actual << '\n';
    std::exit(1);
}
void expect(bool actual, const char *description) { if (actual) return; std::cerr << description << '\n'; std::exit(1); }
}

int main()
{
    Workbook workbook;
    expect(!workbook.isModified(), "new workbook should be clean");
    workbook.setRawValue(0, 0, "5");
    workbook.setRawValue(0, 1, "=A1+A1");
    expect(workbook.displayValue(0, 1), "10", "formula display");
    expect(workbook.isModified(), "edit should mark workbook dirty");
    const auto firstRevision = workbook.revision();
    const auto snapshot = workbook.snapshot();
    workbook.setRawValue(0, 0, "7");
    expect(snapshot.cells[0][0], "5", "snapshot must be immutable copy");
    expect(workbook.revision() > firstRevision, "edits should advance revision");
    expect(workbook.selectionText(0, 0, 0, 1), "7\t=A1+A1", "selection text uses raw values");
    workbook.pasteText(1, 0, "left\tright\nbelow\tcell");
    expect(workbook.rawValue(2, 1), "cell", "range paste");
    workbook.clearRange(1, 0, 2, 1);
    expect(workbook.rawValue(2, 1), "", "range clear");
    const auto token = workbook.beginOperation();
    workbook.cancelOperations();
    expect(token->isCancelled(), "close seam should cancel pending operation");

    const auto path = std::filesystem::temp_directory_path() / "retro-spreadsheet-workbook-test.csv";
    std::string error;
    workbook.setRawValue(1, 0, "value,with,commas");
    workbook.setRawValue(1, 1, "quoted \"value\"");
    expect(workbook.saveCsv(path.string(), &error), "CSV save should succeed");
    Workbook loaded;
    expect(loaded.loadCsv(path.string(), &error), "CSV load should succeed");
    expect(loaded.rawValue(1, 0), "value,with,commas", "CSV comma round trip");
    expect(loaded.rawValue(1, 1), "quoted \"value\"", "CSV quote round trip");
    std::filesystem::remove(path);
    return 0;
}

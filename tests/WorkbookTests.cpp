#define RETRO_SPREADSHEET_TEST_MAIN
#include "TestHarness.h"
#include "RetroSpreadsheet/Workbook.h"

#include <cstdio>
#include <filesystem>

TEST(Workbook_RecalculatesDependentCells)
{
    Workbook workbook;
    workbook.setRawValue(0, 0, "2");
    workbook.setRawValue(0, 1, "=A1");
    workbook.setRawValue(0, 2, "=A1+B1");
    REQUIRE_EQUAL(workbook.displayValue(0, 2), "4");
    workbook.setRawValue(0, 0, "5");
    REQUIRE_EQUAL(workbook.displayValue(0, 1), "5");
    REQUIRE_EQUAL(workbook.displayValue(0, 2), "10");
}

TEST(Workbook_RejectsOutOfBoundsCellAccess)
{
    Workbook workbook;
    workbook.setRawValue(-1, 0, "ignored");
    workbook.setRawValue(Workbook::RowCount, 0, "ignored");
    REQUIRE_EQUAL(workbook.rawValue(-1, 0), "");
    REQUIRE_EQUAL(workbook.displayValue(0, Workbook::ColumnCount), "");
    REQUIRE(!workbook.isModified());
}

TEST(Workbook_UndoRedoRestoresCellContentsAndModifiedState)
{
    Workbook workbook;
    workbook.setRawValue(0, 0, "first");
    workbook.markSaved();
    workbook.setRawValue(0, 0, "second");
    REQUIRE(workbook.canUndo());
    REQUIRE(workbook.undo());
    REQUIRE_EQUAL(workbook.rawValue(0, 0), "first");
    REQUIRE(!workbook.isModified());
    REQUIRE(workbook.redo());
    REQUIRE_EQUAL(workbook.rawValue(0, 0), "second");
    REQUIRE(workbook.isModified());
}

TEST(Workbook_PasteClearAndSelectionRespectBoundaries)
{
    Workbook workbook;
    workbook.pasteText(0, 0, "one\ttwo\nthree\tfour");
    REQUIRE_EQUAL(workbook.selectionText(0, 0, 1, 1), "one\ttwo\nthree\tfour");
    workbook.clearRange(-2, 1, 0, 99);
    REQUIRE_EQUAL(workbook.rawValue(0, 0), "one");
    REQUIRE_EQUAL(workbook.rawValue(0, 1), "");
    REQUIRE(workbook.undo());
    REQUIRE_EQUAL(workbook.rawValue(0, 1), "two");
}

TEST(Workbook_CSVRoundTripsQuotedFormulas)
{
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "retro-spreadsheet-test.csv";
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
    Workbook source;
    source.setRawValue(0, 0, "comma,value");
    source.setRawValue(0, 1, "quote \"value\"");
    source.setRawValue(1, 0, "=SUM(A1:A1)");
    std::string error;
    REQUIRE(source.saveCsv(path.string(), &error));
    Workbook reloaded;
    REQUIRE(reloaded.loadCsv(path.string(), &error));
    REQUIRE_EQUAL(reloaded.rawValue(0, 0), "comma,value");
    REQUIRE_EQUAL(reloaded.rawValue(0, 1), "quote \"value\"");
    REQUIRE_EQUAL(reloaded.displayValue(1, 0), "#VALUE!");
    std::filesystem::remove(path, ignored);
}

TEST(Workbook_CSVReportsFileErrors)
{
    Workbook workbook;
    std::string error;
    REQUIRE(!workbook.loadCsv("/path/that/does/not/exist.csv", &error));
    REQUIRE_EQUAL(error, "The file could not be opened.");
}

TEST(Workbook_SnapshotsAndCancellationTrackOperations)
{
    Workbook workbook;
    const auto initial = workbook.snapshot();
    workbook.setRawValue(0, 0, "value");
    REQUIRE(!workbook.isCurrentRevision(initial.revision));
    const auto operation = workbook.beginOperation();
    REQUIRE(!operation->isCancelled());
    workbook.cancelOperations();
    REQUIRE(operation->isCancelled());
}

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
    REQUIRE(!workbook.pasteText(-1, 0, "ignored"));
    REQUIRE(!workbook.pasteText(0, Workbook::ColumnCount, "ignored"));
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

TEST(Workbook_SnapshotEvaluationIsIndependentFromLaterMutations)
{
    Workbook workbook;
    workbook.setRawValue(0, 0, "2");
    workbook.setRawValue(0, 1, "=A1+A1");
    const auto snapshot = workbook.snapshot();
    workbook.setRawValue(0, 0, "5");

    const auto evaluation = Workbook::evaluateSnapshot(snapshot);
    REQUIRE_EQUAL(evaluation.displayValues[0][1], "4");
    REQUIRE(evaluation.revision == snapshot.revision);
    REQUIRE(!workbook.isCurrentRevision(evaluation.revision));
}

TEST(Workbook_NoOpMutationsDoNotCreateUndoHistory)
{
    Workbook workbook;
    REQUIRE(!workbook.setRawValue(0, 0, ""));
    REQUIRE(!workbook.clearRange(0, 0, 0, 0));
    REQUIRE(!workbook.pasteText(0, 0, ""));
    REQUIRE(!workbook.canUndo());
}

TEST(Workbook_PreservesPortableCellFormattingThroughUndoRedoAndRecalculation)
{
    Workbook workbook;
    CellFormat format;
    format.fontFamily = "Courier";
    format.fontSize = 14.0;
    format.bold = true;
    format.italic = true;
    format.underline = true;
    format.alignment = HorizontalAlignment::Center;

    REQUIRE(workbook.setCellFormat(0, 0, format));
    workbook.setRawValue(0, 0, "2");
    workbook.setRawValue(0, 1, "=A1");
    REQUIRE(workbook.cellFormat(0, 0) == format);
    REQUIRE_EQUAL(workbook.displayValue(0, 1), "2");
    REQUIRE(workbook.undo());
    REQUIRE(workbook.undo());
    REQUIRE(workbook.cellFormat(0, 0) == format);
    REQUIRE(workbook.undo());
    REQUIRE(workbook.cellFormat(0, 0) == CellFormat{});
    REQUIRE(workbook.redo());
    REQUIRE(workbook.cellFormat(0, 0) == format);
}

TEST(Workbook_CsvDoesNotPersistFormatting)
{
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "retro-spreadsheet-format-test.csv";
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
    Workbook source;
    CellFormat format;
    format.bold = true;
    format.alignment = HorizontalAlignment::Right;
    source.setRawValue(0, 0, "=SUM(B1:B1)");
    source.setCellFormat(0, 0, format);
    std::string error;
    REQUIRE(source.saveCsv(path.string(), &error));
    Workbook reloaded;
    REQUIRE(reloaded.loadCsv(path.string(), &error));
    REQUIRE_EQUAL(reloaded.rawValue(0, 0), "=SUM(B1:B1)");
    REQUIRE(reloaded.cellFormat(0, 0) == CellFormat{});
    std::filesystem::remove(path, ignored);
}

TEST(Workbook_AppliesValidatedFormattingToRectangularRangesInOneUndoStep)
{
    Workbook workbook;
    CellFormat format;
    format.fontFamily = "Times-Roman";
    format.fontSize = 18.0;
    format.alignment = HorizontalAlignment::Right;
    REQUIRE(workbook.setFormatRange(0, 0, 1, 1, format));
    REQUIRE(workbook.cellFormat(1, 1) == format);
    REQUIRE(workbook.cellFormat(2, 2) == CellFormat{});
    REQUIRE(workbook.undo());
    REQUIRE(workbook.cellFormat(0, 0) == CellFormat{});
    CellFormat invalid = format;
    invalid.fontSize = 0.0;
    REQUIRE(!workbook.setCellFormat(0, 0, invalid));
    REQUIRE(!workbook.setFormatRange(-4, -4, -1, -1, format));
}

TEST(Workbook_ClearRemovesFormattingWithoutCellValues)
{
    Workbook workbook;
    CellFormat format;
    format.bold = true;
    REQUIRE(workbook.setCellFormat(0, 0, format));

    workbook.clear();

    REQUIRE(workbook.cellFormat(0, 0) == CellFormat{});
    REQUIRE(workbook.canUndo());
    REQUIRE(workbook.undo());
    REQUIRE(workbook.cellFormat(0, 0) == format);
}

TEST(Workbook_FormattingRangePreservesRawValuesFormulasAndEmptyCells)
{
    Workbook workbook;
    workbook.setRawValue(0, 0, "42");
    workbook.setRawValue(0, 1, "=A1*A1");
    CellFormat format;
    format.fontFamily = "Courier";
    format.fontSize = 18.0;
    format.bold = true;
    format.italic = true;
    format.underline = true;
    format.alignment = HorizontalAlignment::Right;

    REQUIRE(workbook.setFormatRange(0, 0, 1, 2, format));
    REQUIRE_EQUAL(workbook.rawValue(0, 0), "42");
    REQUIRE_EQUAL(workbook.rawValue(0, 1), "=A1*A1");
    REQUIRE_EQUAL(workbook.rawValue(1, 2), "");
    REQUIRE_EQUAL(workbook.displayValue(0, 1), "1764");
    REQUIRE(workbook.cellFormat(1, 2) == format);
    REQUIRE(workbook.undo());
    REQUIRE_EQUAL(workbook.rawValue(0, 1), "=A1*A1");
    REQUIRE(workbook.cellFormat(1, 2) == CellFormat{});
    REQUIRE(workbook.redo());
    REQUIRE_EQUAL(workbook.rawValue(0, 1), "=A1*A1");
    REQUIRE(workbook.cellFormat(1, 2) == format);
}

TEST(Workbook_MixedCellAndFormattingUndoRedoRecalculatesWithoutLosingFormats)
{
    Workbook workbook;
    CellFormat format;
    format.alignment = HorizontalAlignment::Center;
    REQUIRE(workbook.setRawValue(0, 0, "2"));
    REQUIRE(workbook.setRawValue(0, 1, "=A1+A1"));
    REQUIRE(workbook.setCellFormat(0, 1, format));
    REQUIRE(workbook.setRawValue(0, 0, "5"));
    REQUIRE_EQUAL(workbook.displayValue(0, 1), "10");
    REQUIRE(workbook.undo());
    REQUIRE_EQUAL(workbook.displayValue(0, 1), "4");
    REQUIRE(workbook.cellFormat(0, 1) == format);
    REQUIRE(workbook.undo());
    REQUIRE(workbook.cellFormat(0, 1) == CellFormat{});
    REQUIRE(workbook.redo());
    REQUIRE(workbook.cellFormat(0, 1) == format);
    REQUIRE(workbook.redo());
    REQUIRE_EQUAL(workbook.displayValue(0, 1), "10");
}

TEST(Workbook_ClearFormattingOnlyWorkbookIsUndoableAndCsvOmitsTheFormat)
{
    const std::filesystem::path path = std::filesystem::temp_directory_path() / "retro-spreadsheet-format-only.csv";
    std::error_code ignored;
    std::filesystem::remove(path, ignored);
    Workbook workbook;
    CellFormat format;
    format.underline = true;
    REQUIRE(workbook.setCellFormat(0, 0, format));
    workbook.clear();
    REQUIRE(workbook.cellFormat(0, 0) == CellFormat{});
    REQUIRE(workbook.undo());
    REQUIRE(workbook.cellFormat(0, 0) == format);
    std::string error;
    REQUIRE(workbook.saveCsv(path.string(), &error));
    Workbook reloaded;
    REQUIRE(reloaded.loadCsv(path.string(), &error));
    REQUIRE_EQUAL(reloaded.rawValue(0, 0), "");
    REQUIRE(reloaded.cellFormat(0, 0) == CellFormat{});
    std::filesystem::remove(path, ignored);
}

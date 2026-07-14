#include "RetroSpreadsheet/Workbook.h"

#include <algorithm>
#include <fstream>
#include <sstream>

bool CellFormat::operator==(const CellFormat &other) const
{
    return fontFamily == other.fontFamily && fontSize == other.fontSize && bold == other.bold
        && italic == other.italic && underline == other.underline && alignment == other.alignment;
}

Workbook::Workbook()
    : cells_(RowCount, std::vector<std::string>(ColumnCount))
    , displayValues_(RowCount, std::vector<std::string>(ColumnCount))
    , formats_(RowCount, std::vector<CellFormat>(ColumnCount))
{
    recalculate();
}

void Workbook::clear()
{
    bool changed = false;
    for (const auto &row : cells_) for (const auto &value : row) if (!value.empty()) { changed = true; break; }
    if (!changed) return;
    recordUndoState();
    for (auto &row : cells_) std::fill(row.begin(), row.end(), std::string());
    for (auto &row : formats_) std::fill(row.begin(), row.end(), CellFormat{});
    recalculate();
    didMutate();
}

bool Workbook::canUndo() const { return !undoStates_.empty(); }
bool Workbook::canRedo() const { return !redoStates_.empty(); }
bool Workbook::undo()
{
    if (!canUndo()) return false;
    redoStates_.push_back({cells_, formats_, modified_});
    const State state = undoStates_.back(); undoStates_.pop_back();
    cells_ = state.cells; formats_ = state.formats; modified_ = state.modified; recalculate(); ++revision_;
    return true;
}
bool Workbook::redo()
{
    if (!canRedo()) return false;
    undoStates_.push_back({cells_, formats_, modified_});
    const State state = redoStates_.back(); redoStates_.pop_back();
    cells_ = state.cells; formats_ = state.formats; modified_ = state.modified; recalculate(); ++revision_;
    return true;
}

bool Workbook::isModified() const { return modified_; }
void Workbook::markSaved() { modified_ = false; }
std::uint64_t Workbook::revision() const { return revision_; }
bool Workbook::isCurrentRevision(std::uint64_t revision) const { return revision_ == revision; }
Workbook::Snapshot Workbook::snapshot() const { return {cells_, revision_}; }

Workbook::Evaluation Workbook::evaluateSnapshot(const Snapshot &snapshot)
{
    Evaluation evaluation{FormulaEvaluator::Grid(snapshot.cells.size()), snapshot.revision};
    FormulaEvaluator evaluator(snapshot.cells);
    for (size_t row = 0; row < snapshot.cells.size(); ++row) {
        evaluation.displayValues[row].resize(snapshot.cells[row].size());
        for (size_t column = 0; column < snapshot.cells[row].size(); ++column)
            evaluation.displayValues[row][column] = snapshot.cells[row][column].empty() ? "" : evaluator.evaluateCell(static_cast<int>(row), static_cast<int>(column));
    }
    return evaluation;
}

std::string Workbook::rawValue(int row, int column) const { return validCell(row, column) ? cells_[row][column] : std::string(); }
std::string Workbook::displayValue(int row, int column) const { return validCell(row, column) ? displayValues_[row][column] : std::string(); }
CellFormat Workbook::cellFormat(int row, int column) const { return validCell(row, column) ? formats_[row][column] : CellFormat{}; }

bool Workbook::setRawValue(int row, int column, const std::string &value)
{
    if (!validCell(row, column) || cells_[row][column] == value) return false;
    recordUndoState();
    cells_[row][column] = value;
    recalculate();
    didMutate();
    return true;
}

bool Workbook::setCellFormat(int row, int column, const CellFormat &format)
{
    if (!validCell(row, column) || !validFormat(format) || formats_[row][column] == format) return false;
    recordUndoState();
    formats_[row][column] = format;
    didMutate();
    return true;
}

bool Workbook::setFormatRange(int firstRow, int firstColumn, int lastRow, int lastColumn, const CellFormat &format)
{
    if (!validFormat(format)) return false;
    firstRow = std::max(firstRow, 0); firstColumn = std::max(firstColumn, 0);
    lastRow = std::min(lastRow, RowCount - 1); lastColumn = std::min(lastColumn, ColumnCount - 1);
    if (firstRow > lastRow || firstColumn > lastColumn) return false;
    bool changed = false;
    for (int row = firstRow; row <= lastRow; ++row) for (int column = firstColumn; column <= lastColumn; ++column)
        if (formats_[row][column] != format) changed = true;
    if (!changed) return false;
    recordUndoState();
    for (int row = firstRow; row <= lastRow; ++row) for (int column = firstColumn; column <= lastColumn; ++column) formats_[row][column] = format;
    didMutate();
    return true;
}

bool Workbook::loadCsv(const std::string &path, std::string *errorMessage)
{
    std::ifstream input(path, std::ios::binary);
    if (!input) { if (errorMessage) *errorMessage = "The file could not be opened."; return false; }
    std::ostringstream buffer;
    buffer << input.rdbuf();
    if (!input.good() && !input.eof()) { if (errorMessage) *errorMessage = "The file could not be read."; return false; }
    for (auto &row : cells_) std::fill(row.begin(), row.end(), std::string());
    for (auto &row : formats_) std::fill(row.begin(), row.end(), CellFormat{});
    int row = 0;
    int column = 0;
    std::string value;
    bool quoted = false;
    const auto placeValue = [&] {
        if (row < RowCount && column < ColumnCount) cells_[row][column] = value;
        value.clear();
    };
    const std::string contents = buffer.str();
    for (size_t index = 0; index < contents.size(); ++index) {
        const char character = contents[index];
        if (character == '"') {
            if (quoted && index + 1 < contents.size() && contents[index + 1] == '"') { value += character; ++index; }
            else quoted = !quoted;
        } else if (character == ',' && !quoted) { placeValue(); ++column; }
        else if ((character == '\n' || character == '\r') && !quoted) {
            if (character == '\r' && index + 1 < contents.size() && contents[index + 1] == '\n') ++index;
            placeValue(); ++row; column = 0;
            if (row >= RowCount) break;
        } else value += character;
    }
    if (row < RowCount && (column != 0 || !value.empty())) placeValue();
    recalculate();
    modified_ = false;
    undoStates_.clear();
    redoStates_.clear();
    ++revision_;
    return true;
}

bool Workbook::saveCsv(const std::string &path, std::string *errorMessage)
{
    std::ofstream output(path, std::ios::trunc | std::ios::binary);
    if (!output) { if (errorMessage) *errorMessage = "The file could not be created."; return false; }
    for (const auto &row : cells_) {
        for (int column = 0; column < ColumnCount; ++column) {
            if (column) output << ',';
            output << escapeCsvValue(row[column]);
        }
        output << '\n';
    }
    if (!output) { if (errorMessage) *errorMessage = "The file could not be saved."; return false; }
    modified_ = false;
    return true;
}

std::string Workbook::selectionText(int firstRow, int firstColumn, int lastRow, int lastColumn) const
{
    std::ostringstream output;
    firstRow = std::max(firstRow, 0); firstColumn = std::max(firstColumn, 0);
    lastRow = std::min(lastRow, RowCount - 1); lastColumn = std::min(lastColumn, ColumnCount - 1);
    for (int row = firstRow; row <= lastRow; ++row) {
        if (row != firstRow) output << '\n';
        for (int column = firstColumn; column <= lastColumn; ++column) {
            if (column != firstColumn) output << '\t';
            output << cells_[row][column];
        }
    }
    return output.str();
}

bool Workbook::pasteText(int startRow, int startColumn, const std::string &text)
{
    if (!validCell(startRow, startColumn)) return false;
    const State previous{cells_, formats_, modified_};
    std::istringstream rows(text);
    std::string rowText;
    bool changed = false;
    for (int row = startRow; row < RowCount && std::getline(rows, rowText); ++row) {
        if (!rowText.empty() && rowText.back() == '\r') rowText.pop_back();
        std::istringstream columns(rowText);
        std::string value;
        for (int column = startColumn; column < ColumnCount && std::getline(columns, value, '\t'); ++column) {
            if (cells_[row][column] != value) { cells_[row][column] = value; changed = true; }
        }
    }
    if (!changed) return false;
    undoStates_.push_back(previous); redoStates_.clear(); recalculate(); didMutate();
    return true;
}

bool Workbook::clearRange(int firstRow, int firstColumn, int lastRow, int lastColumn)
{
    const State previous{cells_, formats_, modified_};
    bool changed = false;
    for (int row = std::max(0, firstRow); row <= std::min(RowCount - 1, lastRow); ++row)
        for (int column = std::max(0, firstColumn); column <= std::min(ColumnCount - 1, lastColumn); ++column)
            if (!cells_[row][column].empty()) { cells_[row][column].clear(); changed = true; }
    if (!changed) return false;
    undoStates_.push_back(previous); redoStates_.clear(); recalculate(); didMutate();
    return true;
}

void Workbook::recalculate()
{
    displayValues_ = evaluateSnapshot(snapshot()).displayValues;
}

void Workbook::didMutate() { modified_ = true; ++revision_; }
void Workbook::recordUndoState() { undoStates_.push_back({cells_, formats_, modified_}); redoStates_.clear(); }

std::string Workbook::escapeCsvValue(const std::string &value)
{
    if (value.find_first_of(",\"\n\r") == std::string::npos) return value;
    std::string escaped = "\"";
    for (char character : value) { if (character == '"') escaped += '"'; escaped += character; }
    return escaped + '"';
}

bool Workbook::validCell(int row, int column) { return row >= 0 && row < RowCount && column >= 0 && column < ColumnCount; }
bool Workbook::validFormat(const CellFormat &format)
{
    return !format.fontFamily.empty() && format.fontSize >= 6.0 && format.fontSize <= 144.0
        && (format.alignment == HorizontalAlignment::Left || format.alignment == HorizontalAlignment::Center || format.alignment == HorizontalAlignment::Right);
}

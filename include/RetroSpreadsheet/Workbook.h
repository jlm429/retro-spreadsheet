#pragma once

#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <cstdint>
#include <string>
#include <vector>

// Portable worksheet model with no AppKit dependency. A Workbook is mutable and
// not safe for concurrent access. Use Snapshot and evaluateSnapshot() to move
// read-only calculation to background work in the future.
class Workbook
{
public:
    static constexpr int RowCount = 20;
    static constexpr int ColumnCount = 10;
    struct Snapshot { FormulaEvaluator::Grid cells; std::uint64_t revision; };
    struct Evaluation { FormulaEvaluator::Grid displayValues; std::uint64_t revision; };

    Workbook();
    void clear();
    bool canUndo() const;
    bool canRedo() const;
    bool undo();
    bool redo();
    bool isModified() const;
    void markSaved();
    std::uint64_t revision() const;
    bool isCurrentRevision(std::uint64_t revision) const;
    Snapshot snapshot() const;
    static Evaluation evaluateSnapshot(const Snapshot &snapshot);

    std::string rawValue(int row, int column) const;
    std::string displayValue(int row, int column) const;
    bool setRawValue(int row, int column, const std::string &value);
    bool loadCsv(const std::string &path, std::string *errorMessage);
    bool saveCsv(const std::string &path, std::string *errorMessage);
    std::string selectionText(int firstRow, int firstColumn, int lastRow, int lastColumn) const;
    bool pasteText(int startRow, int startColumn, const std::string &text);
    bool clearRange(int firstRow, int firstColumn, int lastRow, int lastColumn);

private:
    struct State { FormulaEvaluator::Grid cells; bool modified; };
    FormulaEvaluator::Grid cells_;
    FormulaEvaluator::Grid displayValues_;
    std::uint64_t revision_ = 0;
    bool modified_ = false;
    std::vector<State> undoStates_;
    std::vector<State> redoStates_;
    void recalculate();
    void didMutate();
    void recordUndoState();
    static std::string escapeCsvValue(const std::string &value);
    static bool validCell(int row, int column);
};

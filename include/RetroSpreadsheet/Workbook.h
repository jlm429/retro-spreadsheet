#pragma once

#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <atomic>
#include <cstdint>
#include <memory>
#include <string>

// Portable, main-thread-owned worksheet model. The snapshot and cancellation
// types are deliberate seams for future per-document background operations.
class Workbook
{
public:
    static constexpr int RowCount = 20;
    static constexpr int ColumnCount = 10;
    struct Snapshot { FormulaEvaluator::Grid cells; std::uint64_t revision; };
    class CancellationToken { public: void cancel() { cancelled_.store(true); } bool isCancelled() const { return cancelled_.load(); } private: std::atomic_bool cancelled_{false}; };

    Workbook();
    void clear();
    bool isModified() const;
    void markSaved();
    std::uint64_t revision() const;
    bool isCurrentRevision(std::uint64_t revision) const;
    Snapshot snapshot() const;
    std::shared_ptr<CancellationToken> beginOperation();
    void cancelOperations();

    std::string rawValue(int row, int column) const;
    std::string displayValue(int row, int column) const;
    void setRawValue(int row, int column, const std::string &value);
    bool loadCsv(const std::string &path, std::string *errorMessage);
    bool saveCsv(const std::string &path, std::string *errorMessage);
    std::string selectionText(int firstRow, int firstColumn, int lastRow, int lastColumn) const;
    void pasteText(int startRow, int startColumn, const std::string &text);
    void clearRange(int firstRow, int firstColumn, int lastRow, int lastColumn);

private:
    FormulaEvaluator::Grid cells_;
    FormulaEvaluator::Grid displayValues_;
    std::uint64_t revision_ = 0;
    bool modified_ = false;
    std::shared_ptr<CancellationToken> operationToken_;
    void recalculate();
    void didMutate();
    static std::string escapeCsvValue(const std::string &value);
    static bool validCell(int row, int column);
};

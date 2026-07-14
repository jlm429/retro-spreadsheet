#include "RetroSpreadsheet/FormulaEditingSession.h"

#include <algorithm>

namespace {
std::string columnName(int column)
{
    std::string result;
    for (++column; column > 0; column = (column - 1) / 26) result.insert(result.begin(), static_cast<char>('A' + (column - 1) % 26));
    return result;
}
}

void FormulaEditingSession::begin(Cell destination, const std::string &originalContents)
{
    editing_ = true;
    destination_ = destination;
    referenceRange_ = {destination, destination};
    originalContents_ = originalContents;
    draft_ = originalContents;
}

void FormulaEditingSession::beginFunction(Cell destination, const std::string &originalContents, const std::string &functionName)
{
    begin(destination, originalContents);
    draft_.clear();
    insertFunction(functionName, 0);
}

bool FormulaEditingSession::isEditing() const { return editing_; }
FormulaEditingSession::Cell FormulaEditingSession::destination() const { return destination_; }
const std::string &FormulaEditingSession::originalContents() const { return originalContents_; }
const std::string &FormulaEditingSession::draft() const { return draft_; }
void FormulaEditingSession::setDraft(const std::string &value) { if (editing_) draft_ = value; }
void FormulaEditingSession::setReferenceRange(Range range) { if (editing_) referenceRange_ = range; }

void FormulaEditingSession::insertReference(Range range, std::size_t insertionOffset)
{
    if (!editing_) return;
    referenceRange_ = range;
    const std::string reference = referenceText(range);
    insertionOffset = std::min(insertionOffset, draft_.size());
    draft_.insert(insertionOffset, reference);
}

bool FormulaEditingSession::insertFunction(const std::string &functionName, std::size_t insertionOffset)
{
    if (!editing_ || !isSupportedFunction(functionName)) return false;
    insertionOffset = std::min(insertionOffset, draft_.size());
    const std::string prefix = draft_.empty() ? "=" : "";
    draft_.insert(insertionOffset, prefix + functionName + "(");
    return true;
}

FormulaEditingSession::Range FormulaEditingSession::referenceRange() const { return referenceRange_; }

std::string FormulaEditingSession::commit()
{
    editing_ = false;
    return draft_;
}

std::string FormulaEditingSession::cancel()
{
    editing_ = false;
    draft_ = originalContents_;
    return originalContents_;
}

std::string FormulaEditingSession::referenceText(Range range)
{
    const int firstRow = std::min(range.first.row, range.last.row);
    const int lastRow = std::max(range.first.row, range.last.row);
    const int firstColumn = std::min(range.first.column, range.last.column);
    const int lastColumn = std::max(range.first.column, range.last.column);
    const std::string first = columnName(firstColumn) + std::to_string(firstRow + 1);
    const std::string last = columnName(lastColumn) + std::to_string(lastRow + 1);
    return first == last ? first : first + ":" + last;
}

bool FormulaEditingSession::isSupportedFunction(const std::string &functionName)
{
    return functionName == "SUM" || functionName == "AVERAGE" || functionName == "MIN"
        || functionName == "MAX" || functionName == "COUNT";
}

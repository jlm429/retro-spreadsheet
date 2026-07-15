#include "RetroSpreadsheet/SelectionModel.h"

#include <algorithm>

void SelectionModel::select(Cell cell)
{
    active_ = cell;
    anchor_ = cell;
    last_ = cell;
    kind_ = Kind::Cells;
}

void SelectionModel::extendTo(Cell cell)
{
    active_ = cell;
    last_ = cell;
    kind_ = Kind::Cells;
}

void SelectionModel::selectRow(int row, int activeColumn, int columnCount)
{
    active_ = {row, activeColumn};
    anchor_ = {row, 0};
    last_ = {row, columnCount - 1};
    kind_ = Kind::EntireRow;
}

void SelectionModel::selectColumn(int column, int activeRow, int rowCount)
{
    active_ = {activeRow, column};
    anchor_ = {0, column};
    last_ = {rowCount - 1, column};
    kind_ = Kind::EntireColumn;
}

SelectionModel::Cell SelectionModel::activeCell() const { return active_; }

SelectionModel::Range SelectionModel::range() const
{
    return {{std::min(anchor_.row, last_.row), std::min(anchor_.column, last_.column)},
        {std::max(anchor_.row, last_.row), std::max(anchor_.column, last_.column)}};
}

SelectionModel::Kind SelectionModel::kind() const { return kind_; }

bool SelectionModel::contains(Cell cell) const
{
    const Range selected = range();
    return cell.row >= selected.first.row && cell.row <= selected.last.row
        && cell.column >= selected.first.column && cell.column <= selected.last.column;
}

bool SelectionModel::isActive(Cell cell) const
{
    return cell.row == active_.row && cell.column == active_.column;
}

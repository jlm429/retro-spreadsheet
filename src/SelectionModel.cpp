#include "RetroSpreadsheet/SelectionModel.h"

#include <algorithm>

void SelectionModel::select(Cell cell)
{
    active_ = cell;
    anchor_ = cell;
    last_ = cell;
}

void SelectionModel::extendTo(Cell cell)
{
    active_ = cell;
    last_ = cell;
}

SelectionModel::Cell SelectionModel::activeCell() const { return active_; }

SelectionModel::Range SelectionModel::range() const
{
    return {{std::min(anchor_.row, last_.row), std::min(anchor_.column, last_.column)},
        {std::max(anchor_.row, last_.row), std::max(anchor_.column, last_.column)}};
}

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

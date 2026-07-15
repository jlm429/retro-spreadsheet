#pragma once

// Platform-neutral logical worksheet selection. AppKit owns the visual
// selection, while this value object keeps it stable across control focus.
class SelectionModel
{
public:
    struct Cell { int row = 0; int column = 0; };
    struct Range { Cell first; Cell last; };
    enum class Kind { Cells, EntireRow, EntireColumn };

    SelectionModel() = default;
    explicit SelectionModel(Cell active) : active_(active), anchor_(active), last_(active) {}

    void select(Cell cell);
    void extendTo(Cell cell);
    void selectRow(int row, int activeColumn, int columnCount);
    void selectColumn(int column, int activeRow, int rowCount);
    Cell activeCell() const;
    Range range() const;
    Kind kind() const;
    bool contains(Cell cell) const;
    bool isActive(Cell cell) const;

private:
    Cell active_;
    Cell anchor_;
    Cell last_;
    Kind kind_ = Kind::Cells;
};

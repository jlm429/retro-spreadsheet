#pragma once

// Platform-neutral logical worksheet selection. AppKit owns the visual
// selection, while this value object keeps it stable across control focus.
class SelectionModel
{
public:
    struct Cell { int row = 0; int column = 0; };
    struct Range { Cell first; Cell last; };

    SelectionModel() = default;
    explicit SelectionModel(Cell active) : active_(active), anchor_(active), last_(active) {}

    void select(Cell cell);
    void extendTo(Cell cell);
    Cell activeCell() const;
    Range range() const;
    bool contains(Cell cell) const;
    bool isActive(Cell cell) const;

private:
    Cell active_;
    Cell anchor_;
    Cell last_;
};

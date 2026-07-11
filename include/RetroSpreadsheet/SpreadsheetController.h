#pragma once

#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <QObject>
#include <QStringList>
#include <QTableWidget>

// Owns worksheet state behind a QTableWidget and exposes spreadsheet actions.
class SpreadsheetController : public QObject
{
    Q_OBJECT

public:
    explicit SpreadsheetController(QTableWidget *table, QObject *parent = nullptr);

    // Resets the fixed-size worksheet and clears modified state.
    void newSheet();
    bool isModified() const;

    // Loads and saves raw cell values as CSV. Formula cells are persisted as
    // formulas rather than calculated display values.
    bool openCsv(const QString &fileName, QString *errorMessage);
    bool saveCsv(const QString &fileName, QString *errorMessage);

    // Clipboard operations use tab-separated rows compatible with spreadsheet
    // range copy and paste.
    void copySelectionToClipboard() const;
    void cutSelectionToClipboard();
    void pasteClipboard();

    QString cellRawValue(int row, int column) const;
    void setCellRawValue(int row, int column, const QString &rawValue);

    // Returns A1-style notation for the current contiguous selection.
    QString selectedRangeReference() const;

signals:
    // Emitted when edits, file operations, or new sheets change dirty state.
    void modifiedChanged(bool modified);

private slots:
    void handleItemChanged(QTableWidgetItem *item);

private:
    static constexpr int RowCount = 20;
    static constexpr int ColumnCount = 10;

    QTableWidget *table_;
    FormulaEvaluator::Grid cells_;
    bool updating_ = false;
    bool modified_ = false;

    void configureTable();
    void recalculate();
    void setModified(bool modified);
    void setCell(int row, int column, const QString &rawValue, const QString &displayValue);
    QTableWidgetItem *ensureItem(int row, int column);
    QStringList parseCsvLine(const QString &line) const;
    QString escapeCsvValue(const QString &value) const;
};

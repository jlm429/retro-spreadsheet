#pragma once

#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <QObject>
#include <QStringList>
#include <QTableWidget>

class SpreadsheetController : public QObject
{
    Q_OBJECT

public:
    explicit SpreadsheetController(QTableWidget *table, QObject *parent = nullptr);

    void newSheet();
    bool isModified() const;
    bool openCsv(const QString &fileName, QString *errorMessage);
    bool saveCsv(const QString &fileName, QString *errorMessage);
    void copySelectionToClipboard() const;
    void cutSelectionToClipboard();
    void pasteClipboard();
    QString cellRawValue(int row, int column) const;
    void setCellRawValue(int row, int column, const QString &rawValue);
    QString selectedRangeReference() const;

signals:
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

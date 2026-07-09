#include "RetroSpreadsheet/SpreadsheetController.h"

#include <QAbstractItemView>
#include <QApplication>
#include <QClipboard>
#include <QFile>
#include <QHeaderView>
#include <QTextStream>
#include <algorithm>

namespace {

QString columnName(int column)
{
    QString name;
    int value = column + 1;
    while (value > 0) {
        const int remainder = (value - 1) % 26;
        name.prepend(QChar('A' + remainder));
        value = (value - 1) / 26;
    }
    return name;
}

QString cellReference(int row, int column)
{
    return columnName(column) + QString::number(row + 1);
}

class SpreadsheetItem final : public QTableWidgetItem
{
public:
    QVariant data(int role) const override
    {
        if (role == Qt::EditRole || role == Qt::UserRole) {
            return rawValue_;
        }
        return QTableWidgetItem::data(role);
    }

    void setData(int role, const QVariant &value) override
    {
        if (role == Qt::EditRole) {
            rawValue_ = value.toString();
            QTableWidgetItem::setData(Qt::DisplayRole, rawValue_);
            return;
        }
        QTableWidgetItem::setData(role, value);
    }

    void setRawValue(const QString &value)
    {
        rawValue_ = value;
    }

    void setDisplayValue(const QString &value)
    {
        QTableWidgetItem::setData(Qt::DisplayRole, value);
    }

private:
    QString rawValue_;
};

}

SpreadsheetController::SpreadsheetController(QTableWidget *table, QObject *parent)
    : QObject(parent)
    , table_(table)
    , cells_(RowCount, std::vector<QString>(ColumnCount))
{
    configureTable();
    connect(table_, &QTableWidget::itemChanged, this, &SpreadsheetController::handleItemChanged);
    newSheet();
}

void SpreadsheetController::newSheet()
{
    updating_ = true;
    table_->clearContents();
    for (auto &row : cells_) {
        std::fill(row.begin(), row.end(), QString());
    }
    for (int row = 0; row < RowCount; ++row) {
        for (int column = 0; column < ColumnCount; ++column) {
            setCell(row, column, QString(), QString());
        }
    }
    updating_ = false;
    setModified(false);
}

bool SpreadsheetController::isModified() const
{
    return modified_;
}

bool SpreadsheetController::openCsv(const QString &fileName, QString *errorMessage)
{
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (errorMessage) {
            *errorMessage = file.errorString();
        }
        return false;
    }

    updating_ = true;
    table_->clearContents();
    for (auto &row : cells_) {
        std::fill(row.begin(), row.end(), QString());
    }

    QTextStream stream(&file);
    int row = 0;
    while (!stream.atEnd() && row < RowCount) {
        const QStringList values = parseCsvLine(stream.readLine());
        for (int column = 0; column < values.size() && column < ColumnCount; ++column) {
            cells_[row][column] = values[column];
        }
        ++row;
    }

    for (int currentRow = 0; currentRow < RowCount; ++currentRow) {
        for (int column = 0; column < ColumnCount; ++column) {
            setCell(currentRow, column, cells_[currentRow][column], cells_[currentRow][column]);
        }
    }
    updating_ = false;
    recalculate();
    setModified(false);
    return true;
}

bool SpreadsheetController::saveCsv(const QString &fileName, QString *errorMessage)
{
    QFile file(fileName);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        if (errorMessage) {
            *errorMessage = file.errorString();
        }
        return false;
    }

    QTextStream stream(&file);
    for (int row = 0; row < RowCount; ++row) {
        QStringList values;
        for (int column = 0; column < ColumnCount; ++column) {
            values << escapeCsvValue(cells_[row][column]);
        }
        stream << values.join(',') << '\n';
    }

    setModified(false);
    return true;
}

void SpreadsheetController::copySelectionToClipboard() const
{
    const QList<QTableWidgetSelectionRange> ranges = table_->selectedRanges();
    if (ranges.isEmpty()) {
        return;
    }

    const QTableWidgetSelectionRange range = ranges.first();
    QStringList rows;
    for (int row = range.topRow(); row <= range.bottomRow(); ++row) {
        QStringList values;
        for (int column = range.leftColumn(); column <= range.rightColumn(); ++column) {
            values << cells_[row][column];
        }
        rows << values.join('\t');
    }
    QApplication::clipboard()->setText(rows.join('\n'));
}

void SpreadsheetController::cutSelectionToClipboard()
{
    const QList<QTableWidgetSelectionRange> ranges = table_->selectedRanges();
    if (ranges.isEmpty()) {
        return;
    }

    copySelectionToClipboard();

    updating_ = true;
    for (const QTableWidgetSelectionRange &range : ranges) {
        for (int row = range.topRow(); row <= range.bottomRow(); ++row) {
            for (int column = range.leftColumn(); column <= range.rightColumn(); ++column) {
                cells_[row][column].clear();
                setCell(row, column, QString(), QString());
            }
        }
    }
    updating_ = false;
    recalculate();
    setModified(true);
}

void SpreadsheetController::pasteClipboard()
{
    const QString text = QApplication::clipboard()->text();
    if (text.isEmpty()) {
        return;
    }

    const int startRow = table_->currentRow() >= 0 ? table_->currentRow() : 0;
    const int startColumn = table_->currentColumn() >= 0 ? table_->currentColumn() : 0;
    const QStringList rows = text.split('\n');

    bool changed = false;
    updating_ = true;
    for (int rowOffset = 0; rowOffset < rows.size() && startRow + rowOffset < RowCount; ++rowOffset) {
        const QStringList values = rows[rowOffset].split('\t');
        for (int columnOffset = 0; columnOffset < values.size()
             && startColumn + columnOffset < ColumnCount; ++columnOffset) {
            const int row = startRow + rowOffset;
            const int column = startColumn + columnOffset;
            cells_[row][column] = values[columnOffset];
            setCell(row, column, cells_[row][column], cells_[row][column]);
            changed = true;
        }
    }
    updating_ = false;

    if (changed) {
        recalculate();
        setModified(true);
    }
}

QString SpreadsheetController::cellRawValue(int row, int column) const
{
    if (row < 0 || column < 0 || row >= RowCount || column >= ColumnCount) {
        return QString();
    }
    return cells_[row][column];
}

void SpreadsheetController::setCellRawValue(int row, int column, const QString &rawValue)
{
    if (row < 0 || column < 0 || row >= RowCount || column >= ColumnCount) {
        return;
    }

    cells_[row][column] = rawValue;
    recalculate();
    setModified(true);
}

QString SpreadsheetController::selectedRangeReference() const
{
    const QList<QTableWidgetSelectionRange> ranges = table_->selectedRanges();
    if (ranges.isEmpty()) {
        const int row = table_->currentRow();
        const int column = table_->currentColumn();
        if (row < 0 || column < 0) {
            return QString();
        }
        return cellReference(row, column);
    }

    const QTableWidgetSelectionRange range = ranges.first();
    const QString start = cellReference(range.topRow(), range.leftColumn());
    const QString end = cellReference(range.bottomRow(), range.rightColumn());
    return start == end ? start : start + ':' + end;
}

void SpreadsheetController::handleItemChanged(QTableWidgetItem *item)
{
    if (updating_ || !item) {
        return;
    }

    cells_[item->row()][item->column()] = item->data(Qt::EditRole).toString();
    recalculate();
    setModified(true);
}

void SpreadsheetController::configureTable()
{
    table_->setRowCount(RowCount);
    table_->setColumnCount(ColumnCount);
    table_->setAlternatingRowColors(true);
    table_->setSelectionMode(QAbstractItemView::ContiguousSelection);
    table_->setSelectionBehavior(QAbstractItemView::SelectItems);
    table_->setEditTriggers(QAbstractItemView::DoubleClicked
                            | QAbstractItemView::EditKeyPressed
                            | QAbstractItemView::AnyKeyPressed);

    QStringList headers;
    for (int column = 0; column < ColumnCount; ++column) {
        headers << QString(QChar('A' + column));
    }
    table_->setHorizontalHeaderLabels(headers);

    table_->verticalHeader()->setDefaultSectionSize(28);
    table_->horizontalHeader()->setDefaultSectionSize(96);
    table_->horizontalHeader()->setStretchLastSection(true);
}

void SpreadsheetController::recalculate()
{
    FormulaEvaluator evaluator(cells_);

    updating_ = true;
    for (int row = 0; row < RowCount; ++row) {
        for (int column = 0; column < ColumnCount; ++column) {
            const QString displayValue = cells_[row][column].startsWith('=')
                ? evaluator.evaluateCell(row, column)
                : cells_[row][column];
            setCell(row, column, cells_[row][column], displayValue);
        }
    }
    updating_ = false;
}

void SpreadsheetController::setModified(bool modified)
{
    if (modified_ == modified) {
        return;
    }
    modified_ = modified;
    emit modifiedChanged(modified_);
}

void SpreadsheetController::setCell(int row, int column, const QString &rawValue, const QString &displayValue)
{
    auto *item = static_cast<SpreadsheetItem *>(ensureItem(row, column));
    item->setRawValue(rawValue);
    item->setDisplayValue(displayValue);
}

QTableWidgetItem *SpreadsheetController::ensureItem(int row, int column)
{
    QTableWidgetItem *item = table_->item(row, column);
    if (!item) {
        item = new SpreadsheetItem();
        table_->setItem(row, column, item);
    }
    item->setFlags(item->flags() | Qt::ItemIsEditable);
    return item;
}

QStringList SpreadsheetController::parseCsvLine(const QString &line) const
{
    QStringList values;
    QString current;
    bool quoted = false;

    for (int index = 0; index < line.size(); ++index) {
        const QChar character = line[index];
        if (character == '"') {
            if (quoted && index + 1 < line.size() && line[index + 1] == '"') {
                current += '"';
                ++index;
            } else {
                quoted = !quoted;
            }
        } else if (character == ',' && !quoted) {
            values << current;
            current.clear();
        } else {
            current += character;
        }
    }
    values << current;
    return values;
}

QString SpreadsheetController::escapeCsvValue(const QString &value) const
{
    QString escaped = value;
    if (escaped.contains('"')) {
        escaped.replace("\"", "\"\"");
    }
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
        escaped = '"' + escaped + '"';
    }
    return escaped;
}

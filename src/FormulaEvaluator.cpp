#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <QRegularExpression>
#include <QStringList>
#include <algorithm>
#include <cmath>

FormulaEvaluator::FormulaEvaluator(const Grid &cells)
    : cells_(cells)
{
}

QString FormulaEvaluator::evaluateCell(int row, int column) const
{
    std::vector<std::vector<bool>> visiting(
        cells_.size(),
        std::vector<bool>(cells_.empty() ? 0 : cells_.front().size(), false));
    return evaluateCell(row, column, visiting);
}

QString FormulaEvaluator::evaluateCell(int row, int column, std::vector<std::vector<bool>> &visiting) const
{
    if (row < 0 || column < 0 || row >= static_cast<int>(cells_.size())
        || column >= static_cast<int>(cells_.front().size())) {
        return "#REF!";
    }

    if (visiting[row][column]) {
        return "#CYCLE!";
    }

    const QString raw = cells_[row][column].trimmed();
    if (!raw.startsWith('=')) {
        return raw;
    }

    visiting[row][column] = true;
    const QString result = evaluateFormula(raw, visiting);
    visiting[row][column] = false;
    return result;
}

QString FormulaEvaluator::evaluateFormula(const QString &formula, std::vector<std::vector<bool>> &visiting) const
{
    if (formula.trimmed().mid(1).trimmed().startsWith("SUM", Qt::CaseInsensitive)) {
        return evaluateSum(formula, visiting);
    }
    if (formula.trimmed().mid(1).trimmed().startsWith("AVERAGE", Qt::CaseInsensitive)) {
        return evaluateAverage(formula, visiting);
    }

    static const QRegularExpression referenceExpression(
        R"(^=\s*([A-Za-z]+[1-9][0-9]*)\s*$)");

    const QRegularExpressionMatch referenceMatch = referenceExpression.match(formula);
    if (referenceMatch.hasMatch()) {
        int row = 0;
        int column = 0;
        if (!parseReference(referenceMatch.captured(1), row, column)) {
            return "#REF!";
        }
        return evaluateCell(row, column, visiting);
    }

    static const QRegularExpression expression(
        R"(^=\s*([A-Za-z]+[1-9][0-9]*)\s*([+\-*/])\s*([A-Za-z]+[1-9][0-9]*)\s*$)");

    const QRegularExpressionMatch match = expression.match(formula);
    if (!match.hasMatch()) {
        return "#FORMULA!";
    }

    int leftRow = 0;
    int leftColumn = 0;
    int rightRow = 0;
    int rightColumn = 0;
    if (!parseReference(match.captured(1), leftRow, leftColumn)
        || !parseReference(match.captured(3), rightRow, rightColumn)) {
        return "#REF!";
    }

    bool leftOk = false;
    bool rightOk = false;
    const double left = numericValue(evaluateCell(leftRow, leftColumn, visiting), leftOk);
    const double right = numericValue(evaluateCell(rightRow, rightColumn, visiting), rightOk);
    if (!leftOk || !rightOk) {
        return "#VALUE!";
    }

    double value = 0.0;
    const QString operation = match.captured(2);
    if (operation == "+") {
        value = left + right;
    } else if (operation == "-") {
        value = left - right;
    } else if (operation == "*") {
        value = left * right;
    } else {
        if (right == 0.0) {
            return "#DIV/0!";
        }
        value = left / right;
    }
    return formatNumber(value);
}

QString FormulaEvaluator::evaluateSum(const QString &formula, std::vector<std::vector<bool>> &visiting) const
{
    static const QRegularExpression expression(R"(^=\s*SUM\s*\((.*)\)\s*$)",
                                               QRegularExpression::CaseInsensitiveOption);

    const QRegularExpressionMatch match = expression.match(formula);
    if (!match.hasMatch()) {
        return "#FORMULA!";
    }

    double total = 0.0;
    int count = 0;
    if (!evaluateRangeArguments(match.captured(1), visiting, total, count)) {
        return count < 0 ? "#REF!" : "#VALUE!";
    }
    if (count == 0) {
        return "#FORMULA!";
    }

    return formatNumber(total);
}

QString FormulaEvaluator::evaluateAverage(const QString &formula, std::vector<std::vector<bool>> &visiting) const
{
    static const QRegularExpression expression(R"(^=\s*AVERAGE\s*\((.*)\)\s*$)",
                                               QRegularExpression::CaseInsensitiveOption);

    const QRegularExpressionMatch match = expression.match(formula);
    if (!match.hasMatch()) {
        return "#FORMULA!";
    }

    double total = 0.0;
    int count = 0;
    if (!evaluateRangeArguments(match.captured(1), visiting, total, count)) {
        return count < 0 ? "#REF!" : "#VALUE!";
    }
    if (count == 0) {
        return "#FORMULA!";
    }
    return formatNumber(total / count);
}

bool FormulaEvaluator::evaluateRangeArguments(
    const QString &argumentText,
    std::vector<std::vector<bool>> &visiting,
    double &total,
    int &count) const
{
    const QStringList arguments = argumentText.split(',', Qt::SkipEmptyParts);
    if (arguments.isEmpty()) {
        count = 0;
        return true;
    }

    for (const QString &argument : arguments) {
        int startRow = 0;
        int startColumn = 0;
        int endRow = 0;
        int endColumn = 0;
        if (!parseRange(argument, startRow, startColumn, endRow, endColumn)) {
            count = -1;
            return false;
        }

        for (int row = startRow; row <= endRow; ++row) {
            for (int column = startColumn; column <= endColumn; ++column) {
                bool ok = false;
                total += numericValue(evaluateCell(row, column, visiting), ok);
                if (!ok) {
                    return false;
                }
                ++count;
            }
        }
    }
    return true;
}

bool FormulaEvaluator::parseRange(
    const QString &text, int &startRow, int &startColumn, int &endRow, int &endColumn) const
{
    const QStringList endpoints = text.trimmed().split(':');
    if (endpoints.size() == 1) {
        if (!parseReference(endpoints[0], startRow, startColumn)) {
            return false;
        }
        endRow = startRow;
        endColumn = startColumn;
        return true;
    }

    if (endpoints.size() != 2 || !parseReference(endpoints[0], startRow, startColumn)
        || !parseReference(endpoints[1], endRow, endColumn)) {
        return false;
    }

    if (endRow < startRow) {
        std::swap(startRow, endRow);
    }
    if (endColumn < startColumn) {
        std::swap(startColumn, endColumn);
    }
    return true;
}

QString FormulaEvaluator::formatNumber(double value) const
{
    if (std::floor(value) == value) {
        return QString::number(static_cast<qint64>(value));
    }
    return QString::number(value, 'g', 12);
}

bool FormulaEvaluator::parseReference(const QString &text, int &row, int &column) const
{
    static const QRegularExpression referenceExpression(R"(^([A-Za-z]+)([1-9][0-9]*)$)");

    const QRegularExpressionMatch match = referenceExpression.match(text.trimmed());
    if (!match.hasMatch()) {
        return false;
    }

    int parsedColumn = 0;
    const QString letters = match.captured(1).toUpper();
    for (const QChar character : letters) {
        parsedColumn = parsedColumn * 26 + character.unicode() - 'A' + 1;
    }

    bool rowOk = false;
    const int parsedRow = match.captured(2).toInt(&rowOk);
    if (!rowOk) {
        return false;
    }

    row = parsedRow - 1;
    column = parsedColumn - 1;
    return row >= 0 && column >= 0 && row < static_cast<int>(cells_.size())
        && !cells_.empty() && column < static_cast<int>(cells_.front().size());
}

double FormulaEvaluator::numericValue(const QString &text, bool &ok) const
{
    const QString trimmed = text.trimmed();
    if (trimmed.startsWith('#')) {
        ok = false;
        return 0.0;
    }
    if (trimmed.isEmpty()) {
        ok = true;
        return 0.0;
    }
    return trimmed.toDouble(&ok);
}

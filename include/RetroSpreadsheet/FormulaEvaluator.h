#pragma once

#include <QString>
#include <vector>

class FormulaEvaluator
{
public:
    using Grid = std::vector<std::vector<QString>>;

    explicit FormulaEvaluator(const Grid &cells);

    QString evaluateCell(int row, int column) const;

private:
    const Grid &cells_;

    QString evaluateCell(int row, int column, std::vector<std::vector<bool>> &visiting) const;
    QString evaluateFormula(const QString &formula, std::vector<std::vector<bool>> &visiting) const;
    QString evaluateSum(const QString &formula, std::vector<std::vector<bool>> &visiting) const;
    QString evaluateAverage(const QString &formula, std::vector<std::vector<bool>> &visiting) const;
    bool evaluateRangeArguments(
        const QString &arguments,
        std::vector<std::vector<bool>> &visiting,
        double &total,
        int &count) const;
    bool parseReference(const QString &text, int &row, int &column) const;
    bool parseRange(const QString &text, int &startRow, int &startColumn, int &endRow, int &endColumn) const;
    QString formatNumber(double value) const;
    double numericValue(const QString &text, bool &ok) const;
};

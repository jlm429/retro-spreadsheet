#pragma once

#include <string>
#include <vector>

// Evaluates worksheet formulas without depending on AppKit.
class FormulaEvaluator
{
public:
    using Grid = std::vector<std::vector<std::string>>;

    explicit FormulaEvaluator(const Grid &cells);
    std::string evaluateCell(int row, int column) const;

private:
    const Grid &cells_;

    std::string evaluateCell(int row, int column, std::vector<std::vector<bool>> &visiting) const;
    std::string evaluateFormula(const std::string &formula, std::vector<std::vector<bool>> &visiting) const;
    std::string evaluateAggregate(const std::string &formula, const std::string &function,
                                  std::vector<std::vector<bool>> &visiting) const;
    bool evaluateRangeArguments(const std::string &arguments, std::vector<std::vector<bool>> &visiting,
                                double &total, int &count, bool ignoreText) const;
    bool parseReference(const std::string &text, int &row, int &column) const;
    bool parseRange(const std::string &text, int &startRow, int &startColumn,
                    int &endRow, int &endColumn) const;
    static std::string trim(const std::string &text);
    static std::string uppercase(std::string text);
    static std::string formatNumber(double value);
    static double numericValue(const std::string &text, bool &ok);
};

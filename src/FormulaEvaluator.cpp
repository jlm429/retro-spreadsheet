#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <iomanip>
#include <regex>
#include <sstream>

FormulaEvaluator::FormulaEvaluator(const Grid &cells) : cells_(cells) {}

std::string FormulaEvaluator::evaluateCell(int row, int column) const
{
    std::vector<std::vector<bool>> visiting(cells_.size(), std::vector<bool>(cells_.empty() ? 0 : cells_.front().size()));
    return evaluateCell(row, column, visiting);
}

std::string FormulaEvaluator::evaluateCell(int row, int column, std::vector<std::vector<bool>> &visiting) const
{
    if (cells_.empty() || row < 0 || column < 0 || row >= static_cast<int>(cells_.size())
        || column >= static_cast<int>(cells_.front().size())) return "#REF!";
    if (visiting[row][column]) return "#CYCLE!";
    const std::string raw = trim(cells_[row][column]);
    if (raw.empty() || raw.front() != '=') return raw;
    visiting[row][column] = true;
    const std::string result = evaluateFormula(raw, visiting);
    visiting[row][column] = false;
    return result;
}

std::string FormulaEvaluator::evaluateFormula(const std::string &formula, std::vector<std::vector<bool>> &visiting) const
{
    const std::string upper = uppercase(trim(formula.substr(1)));
    for (const std::string &function : {"SUM", "AVERAGE", "MIN", "MAX", "COUNT"}) {
        if (upper.rfind(function, 0) != 0) continue;
        const std::size_t openingParenthesis = upper.find_first_not_of(" \t\r\n", function.size());
        if (openingParenthesis != std::string::npos && upper[openingParenthesis] == '(')
            return evaluateAggregate(formula, function, visiting);
    }
    static const std::regex reference(R"(^\s*=\s*([A-Za-z]+[1-9][0-9]*)\s*$)");
    static const std::regex binary(R"(^\s*=\s*([A-Za-z]+[1-9][0-9]*)\s*([+\-*/])\s*([A-Za-z]+[1-9][0-9]*)\s*$)");
    std::smatch match;
    if (std::regex_match(formula, match, reference)) {
        int row = 0, column = 0;
        return parseReference(match[1].str(), row, column) ? evaluateCell(row, column, visiting) : "#REF!";
    }
    if (!std::regex_match(formula, match, binary)) return "#FORMULA!";
    int leftRow = 0, leftColumn = 0, rightRow = 0, rightColumn = 0;
    if (!parseReference(match[1].str(), leftRow, leftColumn) || !parseReference(match[3].str(), rightRow, rightColumn)) return "#REF!";
    bool leftOk = false, rightOk = false;
    const double left = numericValue(evaluateCell(leftRow, leftColumn, visiting), leftOk);
    const double right = numericValue(evaluateCell(rightRow, rightColumn, visiting), rightOk);
    if (!leftOk || !rightOk) return "#VALUE!";
    switch (match[2].str()[0]) {
    case '+': return formatNumber(left + right);
    case '-': return formatNumber(left - right);
    case '*': return formatNumber(left * right);
    default: return right == 0.0 ? "#DIV/0!" : formatNumber(left / right);
    }
}

std::string FormulaEvaluator::evaluateAggregate(const std::string &formula, const std::string &function,
                                                std::vector<std::vector<bool>> &visiting) const
{
    const std::regex expression("^\\s*=\\s*" + function + R"(\s*\((.*)\)\s*$)", std::regex::icase);
    std::smatch match;
    if (!std::regex_match(formula, match, expression)) return "#FORMULA!";
    double total = 0.0;
    int count = 0;
    if (!evaluateRangeArguments(match[1].str(), visiting, total, count, function == "COUNT")) {
        if (count == -2) return "#FORMULA!";
        return count < 0 ? "#REF!" : "#VALUE!";
    }
    if (function == "SUM") return formatNumber(total);
    if (function == "COUNT") return formatNumber(count);
    if (count == 0) return "#FORMULA!";

    double result = function == "AVERAGE" ? total / count : 0.0;
    if (function == "MIN" || function == "MAX") {
        bool found = false;
        for (std::stringstream input(match[1].str()); input.good();) {
            std::string argument;
            std::getline(input, argument, ',');
            if (trim(argument).empty()) continue;
            int firstRow = 0, firstColumn = 0, lastRow = 0, lastColumn = 0;
            if (!parseRange(argument, firstRow, firstColumn, lastRow, lastColumn)) return "#REF!";
            for (int row = firstRow; row <= lastRow; ++row) for (int column = firstColumn; column <= lastColumn; ++column) {
                const std::string text = evaluateCell(row, column, visiting);
                if (trim(text).empty()) continue;
                bool ok = false;
                const double value = numericValue(text, ok);
                if (!ok) return "#VALUE!";
                if (!found) { result = value; found = true; }
                else result = function == "MIN" ? std::min(result, value) : std::max(result, value);
            }
        }
    }
    return formatNumber(result);
}

bool FormulaEvaluator::evaluateRangeArguments(const std::string &arguments, std::vector<std::vector<bool>> &visiting,
                                              double &total, int &count, bool ignoreText) const
{
    const std::string trimmedArguments = trim(arguments);
    if (trimmedArguments.empty()) return true;
    if (trimmedArguments.front() == ',' || trimmedArguments.back() == ',') {
        count = -2;
        return false;
    }
    std::stringstream input(arguments);
    std::string argument;
    bool any = false;
    while (std::getline(input, argument, ',')) {
        if (trim(argument).empty()) { count = -2; return false; }
        any = true;
        int firstRow = 0, firstColumn = 0, lastRow = 0, lastColumn = 0;
        if (!parseRange(argument, firstRow, firstColumn, lastRow, lastColumn)) { count = -1; return false; }
        for (int row = firstRow; row <= lastRow; ++row) for (int column = firstColumn; column <= lastColumn; ++column) {
            const std::string value = evaluateCell(row, column, visiting);
            if (trim(value).empty()) continue;
            bool ok = false;
            const double numeric = numericValue(value, ok);
            if (!ok) {
                if (ignoreText && value.front() != '#') continue;
                return false;
            }
            total += numeric;
            ++count;
        }
    }
    return any;
}

bool FormulaEvaluator::parseRange(const std::string &text, int &firstRow, int &firstColumn, int &lastRow, int &lastColumn) const
{
    const auto colon = text.find(':');
    if (colon == std::string::npos) {
        if (!parseReference(text, firstRow, firstColumn)) return false;
        lastRow = firstRow; lastColumn = firstColumn; return true;
    }
    if (!parseReference(text.substr(0, colon), firstRow, firstColumn) || !parseReference(text.substr(colon + 1), lastRow, lastColumn)) return false;
    if (lastRow < firstRow) std::swap(firstRow, lastRow);
    if (lastColumn < firstColumn) std::swap(firstColumn, lastColumn);
    return true;
}

bool FormulaEvaluator::parseReference(const std::string &text, int &row, int &column) const
{
    static const std::regex expression(R"(^\s*([A-Za-z]+)([1-9][0-9]*)\s*$)");
    std::smatch match;
    if (!std::regex_match(text, match, expression)) return false;
    column = 0;
    for (const char character : uppercase(match[1].str())) column = column * 26 + character - 'A' + 1;
    --column;
    try { row = std::stoi(match[2].str()) - 1; } catch (...) { return false; }
    return !cells_.empty() && row >= 0 && column >= 0 && row < static_cast<int>(cells_.size()) && column < static_cast<int>(cells_.front().size());
}

std::string FormulaEvaluator::trim(const std::string &text) { const auto first = text.find_first_not_of(" \t\r\n"); return first == std::string::npos ? "" : text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1); }
std::string FormulaEvaluator::uppercase(std::string text) { std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) { return static_cast<char>(std::toupper(c)); }); return text; }
std::string FormulaEvaluator::formatNumber(double value) { if (std::floor(value) == value) return std::to_string(static_cast<long long>(value)); std::ostringstream output; output << std::setprecision(12) << value; return output.str(); }
double FormulaEvaluator::numericValue(const std::string &text, bool &ok) { const std::string value = trim(text); if (value.empty()) { ok = true; return 0.0; } if (value.front() == '#') { ok = false; return 0.0; } try { size_t consumed = 0; const double result = std::stod(value, &consumed); ok = consumed == value.size(); return result; } catch (...) { ok = false; return 0.0; } }

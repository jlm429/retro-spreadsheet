#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <cstdlib>
#include <iostream>

namespace {
void expect(const std::string &actual, const std::string &expected, const char *description)
{
    if (actual == expected) return;
    std::cerr << description << ": expected " << expected << ", got " << actual << '\n';
    std::exit(1);
}
}

int main()
{
    const FormulaEvaluator::Grid cells = {
        {"6", "3", "=A1+B1", "=A1-B1", "=A1*B1", "=A1/B1"},
        {"4", "5", "=SUM(A1:B2)", "=AVERAGE(A1:B2)", "=A1/Z99", "=A1/F3"},
        {"=B3", "=A3", "not a number", "=C3+A1", "", ""},
    };
    const FormulaEvaluator evaluator(cells);
    expect(evaluator.evaluateCell(0, 2), "9", "addition");
    expect(evaluator.evaluateCell(1, 2), "18", "sum range");
    expect(evaluator.evaluateCell(1, 3), "4.5", "average range");
    expect(evaluator.evaluateCell(1, 4), "#REF!", "invalid reference");
    expect(evaluator.evaluateCell(1, 5), "#DIV/0!", "division by zero");
    expect(evaluator.evaluateCell(2, 0), "#CYCLE!", "cycle detection");
    expect(evaluator.evaluateCell(2, 3), "#VALUE!", "non-numeric value");
    return 0;
}

#include "TestHarness.h"
#include "RetroSpreadsheet/FormulaEvaluator.h"

namespace {
FormulaEvaluator::Grid grid(std::initializer_list<std::initializer_list<const char *>> rows)
{
    FormulaEvaluator::Grid values;
    for (const auto &row : rows) {
        values.emplace_back();
        for (const char *value : row) values.back().emplace_back(value);
    }
    return values;
}
}

TEST(FormulaEvaluator_ReturnsLiteralAndTrimmedValues)
{
    const auto values = grid({{"  hello  ", ""}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 0), "hello");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 1), "");
}

TEST(FormulaEvaluator_EvaluatesReferencesAndArithmetic)
{
    const auto values = grid({{"2", "3", "=A1+B1", "=C1*B1", "=D1/A1", "=E1-B1"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 2), "5");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 3), "15");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 4), "7.5");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 5), "4.5");
}

TEST(FormulaEvaluator_EvaluatesCaseInsensitiveAggregateRanges)
{
    const auto values = grid({{"1", "2", "3"}, {"4", "=sum(A1:A2)", "=AVERAGE(A1:C1)"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(1, 1), "5");
    REQUIRE_EQUAL(evaluator.evaluateCell(1, 2), "2");
}

TEST(FormulaEvaluator_DetectsCircularReferences)
{
    const auto values = grid({{"=B1", "=A1"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 0), "#CYCLE!");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 1), "#CYCLE!");
}

TEST(FormulaEvaluator_ReportsFormulaReferenceAndValueErrors)
{
    const auto values = grid({{"abc", "=A1+B1", "=Z99", "=A1/"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 1), "#VALUE!");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 2), "#REF!");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 3), "#FORMULA!");
    REQUIRE_EQUAL(evaluator.evaluateCell(-1, 0), "#REF!");
}

TEST(FormulaEvaluator_ReportsDivisionByZeroAndInvalidAggregateInput)
{
    const auto values = grid({{"4", "0", "=A1/B1", "=SUM(A1,Z1)", "=AVERAGE()"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 2), "#DIV/0!");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 3), "#REF!");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 4), "#FORMULA!");
}

TEST(FormulaEvaluator_EvaluatesMinMaxAndCountRanges)
{
    const auto values = grid({{"3", "", "8", "text", "=MIN(A1:C1)", "=MAX(A1:C1)", "=COUNT(A1:D1)"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 4), "3");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 5), "8");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 6), "2");
}

TEST(FormulaEvaluator_AllowsWhitespaceBeforeAggregateParentheses)
{
    const auto values = grid({{"2", "3", "=SUM (A1:B1)", "=AVERAGE (A1:B1)", "=MIN (A1:B1)", "=MAX (A1:B1)", "=COUNT (A1:B1)"}});
    const FormulaEvaluator evaluator(values);
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 2), "5");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 3), "2.5");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 4), "2");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 5), "3");
    REQUIRE_EQUAL(evaluator.evaluateCell(0, 6), "2");
}

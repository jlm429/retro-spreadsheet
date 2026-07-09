#include "RetroSpreadsheet/FormulaEvaluator.h"

#include <QtTest/QtTest>

class FormulaEvaluatorTests : public QObject
{
    Q_OBJECT

private slots:
    void evaluatesDirectReferences();
    void evaluatesBasicArithmetic();
    void evaluatesAggregateFunctions();
    void reportsFormulaErrors();
    void followsDependencies();
    void detectsCycles();
};

void FormulaEvaluatorTests::evaluatesDirectReferences()
{
    const FormulaEvaluator::Grid cells = {
        {"42", "=A1"},
    };

    const FormulaEvaluator evaluator(cells);

    QCOMPARE(evaluator.evaluateCell(0, 1), QString("42"));
}

void FormulaEvaluatorTests::evaluatesBasicArithmetic()
{
    const FormulaEvaluator::Grid cells = {
        {"6", "3", "=A1+B1", "=A1-B1", "=A1*B1", "=A1/B1"},
    };

    const FormulaEvaluator evaluator(cells);

    QCOMPARE(evaluator.evaluateCell(0, 2), QString("9"));
    QCOMPARE(evaluator.evaluateCell(0, 3), QString("3"));
    QCOMPARE(evaluator.evaluateCell(0, 4), QString("18"));
    QCOMPARE(evaluator.evaluateCell(0, 5), QString("2"));
}

void FormulaEvaluatorTests::evaluatesAggregateFunctions()
{
    const FormulaEvaluator::Grid cells = {
        {"1", "2", "3"},
        {"4", "5", "=SUM(A1:B2)"},
        {"=AVERAGE(A1:B2)", "=SUM(A1,A2,B2)", ""},
    };

    const FormulaEvaluator evaluator(cells);

    QCOMPARE(evaluator.evaluateCell(1, 2), QString("12"));
    QCOMPARE(evaluator.evaluateCell(2, 0), QString("3"));
    QCOMPARE(evaluator.evaluateCell(2, 1), QString("10"));
}

void FormulaEvaluatorTests::reportsFormulaErrors()
{
    const FormulaEvaluator::Grid cells = {
        {"not a number", "0", "=A1+B1", "=A1/Z99", "=A1", "=B1/B1"},
    };

    const FormulaEvaluator evaluator(cells);

    QCOMPARE(evaluator.evaluateCell(0, 2), QString("#VALUE!"));
    QCOMPARE(evaluator.evaluateCell(0, 3), QString("#REF!"));
    QCOMPARE(evaluator.evaluateCell(0, 5), QString("#DIV/0!"));
}

void FormulaEvaluatorTests::followsDependencies()
{
    FormulaEvaluator::Grid cells = {
        {"5"},
        {"=A1+ A1"},
        {"=A2*A1"},
    };

    FormulaEvaluator evaluator(cells);
    QCOMPARE(evaluator.evaluateCell(2, 0), QString("50"));

    cells[0][0] = "3";
    FormulaEvaluator updatedEvaluator(cells);
    QCOMPARE(updatedEvaluator.evaluateCell(2, 0), QString("18"));
}

void FormulaEvaluatorTests::detectsCycles()
{
    const FormulaEvaluator::Grid cells = {
        {"=A2"},
        {"=A1"},
    };

    const FormulaEvaluator evaluator(cells);

    QCOMPARE(evaluator.evaluateCell(0, 0), QString("#CYCLE!"));
}

QTEST_MAIN(FormulaEvaluatorTests)

#include "FormulaEvaluatorTests.moc"

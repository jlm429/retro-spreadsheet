#include "TestHarness.h"
#include "RetroSpreadsheet/FormulaEditingSession.h"

TEST(FormulaEditingSession_KeepsDestinationSeparateFromReferencedRange)
{
    FormulaEditingSession session;
    session.begin({4, 4}, "old value");
    session.insertReference({{0, 0}, {2, 1}}, 0);
    REQUIRE(session.destination().row == 4);
    REQUIRE(session.destination().column == 4);
    REQUIRE_EQUAL(session.draft(), "A1:B3old value");
    REQUIRE_EQUAL(FormulaEditingSession::referenceText(session.referenceRange()), "A1:B3");
    REQUIRE_EQUAL(session.cancel(), "old value");
    REQUIRE(!session.isEditing());
}

TEST(FormulaEditingSession_FunctionTemplateCommitsAndEscapesToOriginalContent)
{
    FormulaEditingSession session;
    session.beginFunction({1, 1}, "prior", "COUNT");
    session.insertReference({{3, 2}, {3, 2}}, session.draft().size());
    REQUIRE_EQUAL(session.commit(), "=COUNT(C4");
    session.beginFunction({1, 1}, "prior", "MAX");
    REQUIRE_EQUAL(session.cancel(), "prior");
}

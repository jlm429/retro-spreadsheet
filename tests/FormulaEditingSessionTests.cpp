#include "TestHarness.h"
#include "RetroSpreadsheet/FormulaEditingSession.h"

TEST(FormulaEditingSession_KeepsDestinationSeparateFromReferencedRange)
{
    FormulaEditingSession session;
    session.begin({4, 4}, "old value");
    REQUIRE(!session.referenceRange());
    session.insertReference({{0, 0}, {2, 1}}, 0);
    REQUIRE(session.destination().row == 4);
    REQUIRE(session.destination().column == 4);
    REQUIRE_EQUAL(session.draft(), "A1:B3old value");
    REQUIRE_EQUAL(FormulaEditingSession::referenceText(*session.referenceRange()), "A1:B3");
    REQUIRE_EQUAL(session.cancel(), "old value");
    REQUIRE(!session.isEditing());
    REQUIRE(!session.referenceRange());
}

TEST(FormulaEditingSession_FunctionTemplateCommitsAndEscapesToOriginalContent)
{
    FormulaEditingSession session;
    session.beginFunction({1, 1}, "prior", "COUNT");
    session.insertReference({{3, 2}, {3, 2}}, session.draft().size());
    REQUIRE_EQUAL(session.commit(), "=COUNT(C4");
    REQUIRE(!session.referenceRange());
    session.beginFunction({1, 1}, "prior", "MAX");
    REQUIRE_EQUAL(session.cancel(), "prior");
    REQUIRE(!session.referenceRange());
}

TEST(FormulaEditingSession_TracksDraftReferencesAndNoOpCommitWithoutChangingDestination)
{
    FormulaEditingSession session;
    session.begin({2, 3}, "=SUM(A1:A2)");
    session.setDraft("=SUM (A1:A2)");
    session.insertReference({{0, 1}, {1, 1}}, session.draft().size());
    REQUIRE_EQUAL(session.draft(), "=SUM (A1:A2)B1:B2");
    REQUIRE_EQUAL(session.commit(), "=SUM (A1:A2)B1:B2");
    REQUIRE(!session.isEditing());

    session.begin({2, 3}, "unchanged");
    REQUIRE_EQUAL(session.commit(), "unchanged");
    REQUIRE(!session.isEditing());
}

TEST(FormulaEditingSession_InsertsOnlySupportedFunctionsIntoTheDraft)
{
    FormulaEditingSession session;
    session.begin({0, 0}, "");
    REQUIRE(session.insertFunction("SUM", 0));
    REQUIRE_EQUAL(session.draft(), "=SUM(");
    REQUIRE(session.insertFunction("MAX", session.draft().size()));
    REQUIRE_EQUAL(session.draft(), "=SUM(MAX(");
    REQUIRE(!session.insertFunction("MEDIAN", session.draft().size()));
    REQUIRE_EQUAL(session.draft(), "=SUM(MAX(");
}

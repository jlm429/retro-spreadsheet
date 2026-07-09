#include "RetroSpreadsheet/SpreadsheetController.h"

#include <QApplication>
#include <QClipboard>
#include <QSignalSpy>
#include <QTableWidget>
#include <QTemporaryDir>
#include <QtTest/QtTest>

class SpreadsheetControllerTests : public QObject
{
    Q_OBJECT

private slots:
    void updatesFormulaDisplayWhenInputsChange();
    void savesAndOpensCsvRawValues();
    void reportsSelectedRangeReferences();
    void copiesCutsAndPastesRanges();
    void tracksModifiedState();
};

void SpreadsheetControllerTests::updatesFormulaDisplayWhenInputsChange()
{
    QTableWidget table;
    SpreadsheetController controller(&table);

    controller.setCellRawValue(0, 0, "5");
    controller.setCellRawValue(0, 1, "=A1+A1");

    QCOMPARE(table.item(0, 1)->text(), QString("10"));

    controller.setCellRawValue(0, 0, "7");

    QCOMPARE(table.item(0, 1)->text(), QString("14"));
    QCOMPARE(controller.cellRawValue(0, 1), QString("=A1+A1"));
}

void SpreadsheetControllerTests::savesAndOpensCsvRawValues()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath("sheet.csv");

    QTableWidget sourceTable;
    SpreadsheetController source(&sourceTable);
    source.setCellRawValue(0, 0, "plain");
    source.setCellRawValue(0, 1, "value,with,commas");
    source.setCellRawValue(1, 0, "quoted \"value\"");
    source.setCellRawValue(1, 1, "=A1");

    QString error;
    QVERIFY2(source.saveCsv(path, &error), qPrintable(error));

    QTableWidget loadedTable;
    SpreadsheetController loaded(&loadedTable);
    QVERIFY2(loaded.openCsv(path, &error), qPrintable(error));

    QCOMPARE(loaded.cellRawValue(0, 0), QString("plain"));
    QCOMPARE(loaded.cellRawValue(0, 1), QString("value,with,commas"));
    QCOMPARE(loaded.cellRawValue(1, 0), QString("quoted \"value\""));
    QCOMPARE(loaded.cellRawValue(1, 1), QString("=A1"));
    QCOMPARE(loadedTable.item(1, 1)->text(), QString("plain"));
}

void SpreadsheetControllerTests::reportsSelectedRangeReferences()
{
    QTableWidget table;
    SpreadsheetController controller(&table);

    table.setCurrentCell(0, 0);
    QCOMPARE(controller.selectedRangeReference(), QString("A1"));

    table.clearSelection();
    table.setRangeSelected(QTableWidgetSelectionRange(0, 0, 2, 1), true);
    QCOMPARE(controller.selectedRangeReference(), QString("A1:B3"));
}

void SpreadsheetControllerTests::copiesCutsAndPastesRanges()
{
    QTableWidget table;
    SpreadsheetController controller(&table);

    controller.setCellRawValue(0, 0, "left");
    controller.setCellRawValue(0, 1, "right");
    table.setRangeSelected(QTableWidgetSelectionRange(0, 0, 0, 1), true);

    controller.copySelectionToClipboard();
    QCOMPARE(QApplication::clipboard()->text(), QString("left\tright"));

    controller.cutSelectionToClipboard();
    QCOMPARE(controller.cellRawValue(0, 0), QString());
    QCOMPARE(controller.cellRawValue(0, 1), QString());

    QApplication::clipboard()->setText("a\tb\nc\td");
    table.clearSelection();
    table.setCurrentCell(1, 1);
    controller.pasteClipboard();

    QCOMPARE(controller.cellRawValue(1, 1), QString("a"));
    QCOMPARE(controller.cellRawValue(1, 2), QString("b"));
    QCOMPARE(controller.cellRawValue(2, 1), QString("c"));
    QCOMPARE(controller.cellRawValue(2, 2), QString("d"));
}

void SpreadsheetControllerTests::tracksModifiedState()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath("dirty.csv");

    QTableWidget table;
    SpreadsheetController controller(&table);
    QSignalSpy modifiedSpy(&controller, &SpreadsheetController::modifiedChanged);

    QVERIFY(!controller.isModified());

    controller.setCellRawValue(0, 0, "changed");
    QVERIFY(controller.isModified());
    QCOMPARE(modifiedSpy.count(), 1);
    QCOMPARE(modifiedSpy.takeFirst().at(0).toBool(), true);

    QString error;
    QVERIFY2(controller.saveCsv(path, &error), qPrintable(error));
    QVERIFY(!controller.isModified());
    QCOMPARE(modifiedSpy.count(), 1);
    QCOMPARE(modifiedSpy.takeFirst().at(0).toBool(), false);
}

QTEST_MAIN(SpreadsheetControllerTests)

#include "SpreadsheetControllerTests.moc"

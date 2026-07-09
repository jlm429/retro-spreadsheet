#pragma once

#include "RetroSpreadsheet/SpreadsheetController.h"

#include <QAction>
#include <QMainWindow>
#include <QTableWidget>
#include <array>

class QCloseEvent;
class QLineEdit;
class QMenu;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);

private:
    static constexpr int MaxRecentFiles = 5;

    QTableWidget *table_;
    QLineEdit *formulaBar_;
    SpreadsheetController *controller_;
    QString currentFileName_;
    QMenu *recentFilesMenu_;
    std::array<QAction *, MaxRecentFiles> recentFileActions_;
    bool updatingFormulaBar_ = false;
    bool selectingFormulaReference_ = false;
    int formulaTargetRow_ = -1;
    int formulaTargetColumn_ = -1;

    void createCentralWidget();
    void createActions();
    void createFileActions();
    void createEditActions();
    void createFormulaActions();
    void closeEvent(QCloseEvent *event) override;
    void startFormula(const QString &functionName);
    void updateFormulaBarFromCurrentCell();
    void commitFormulaBar();
    void handleFormulaBarEdited(const QString &text);
    void insertSelectedReferenceIntoFormulaBar();
    void newWorkbook();
    void openCsv();
    void openRecentCsv();
    void saveCsv();
    void saveCsvAs();
    bool maybeSave();
    bool saveCsvToFile(const QString &fileName);
    void setCurrentFileName(const QString &fileName);
    void addRecentFile(const QString &fileName);
    QStringList recentFiles() const;
    void updateRecentFileActions();
    void updateWindowTitle();
    void showError(const QString &title, const QString &message);
};

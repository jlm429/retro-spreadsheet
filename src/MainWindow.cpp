#include "RetroSpreadsheet/MainWindow.h"

#include <QAction>
#include <QCloseEvent>
#include <QFileDialog>
#include <QIcon>
#include <QItemSelectionModel>
#include <QLabel>
#include <QLineEdit>
#include <QMenuBar>
#include <QMessageBox>
#include <QSettings>
#include <QStatusBar>
#include <QToolBar>
#include <QFileInfo>
#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QWidget>
#include <algorithm>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , table_(new QTableWidget(this))
    , formulaBar_(new QLineEdit(this))
    , controller_(new SpreadsheetController(table_, this))
    , recentFilesMenu_(nullptr)
    , recentFileActions_()
{
    createCentralWidget();
    createActions();
    connect(controller_, &SpreadsheetController::modifiedChanged, this, [this](bool modified) {
        setWindowModified(modified);
        updateWindowTitle();
    });
    connect(table_, &QTableWidget::currentCellChanged, this, [this]() {
        if (!selectingFormulaReference_) {
            updateFormulaBarFromCurrentCell();
        }
    });
    connect(table_->selectionModel(), &QItemSelectionModel::selectionChanged, this, [this]() {
        insertSelectedReferenceIntoFormulaBar();
    });
    connect(formulaBar_, &QLineEdit::textEdited, this, &MainWindow::handleFormulaBarEdited);
    connect(formulaBar_, &QLineEdit::returnPressed, this, &MainWindow::commitFormulaBar);
    statusBar()->showMessage("Ready");
    resize(980, 620);
    setCurrentFileName(QString());
    updateRecentFileActions();
    updateFormulaBarFromCurrentCell();
}

void MainWindow::createCentralWidget()
{
    auto *centralWidget = new QWidget(this);
    auto *layout = new QVBoxLayout(centralWidget);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);

    auto *formulaLayout = new QHBoxLayout();
    formulaLayout->setContentsMargins(6, 4, 6, 4);
    formulaLayout->setSpacing(6);

    auto *formulaLabel = new QLabel("fx", centralWidget);
    formulaLabel->setAlignment(Qt::AlignCenter);
    formulaLabel->setFixedWidth(28);

    formulaBar_->setClearButtonEnabled(true);
    formulaBar_->setPlaceholderText("=");

    formulaLayout->addWidget(formulaLabel);
    formulaLayout->addWidget(formulaBar_);
    layout->addLayout(formulaLayout);
    layout->addWidget(table_);

    setCentralWidget(centralWidget);
}

void MainWindow::createActions()
{
    createFileActions();
    createEditActions();
    createFormulaActions();
}

void MainWindow::createFileActions()
{
    auto *fileMenu = menuBar()->addMenu("&File");
    auto *fileToolbar = addToolBar("File");
    fileToolbar->setMovable(false);

    auto *newAction = new QAction(QIcon::fromTheme("document-new"), "&New", this);
    newAction->setShortcut(QKeySequence::New);
    connect(newAction, &QAction::triggered, this, &MainWindow::newWorkbook);

    auto *openAction = new QAction(QIcon::fromTheme("document-open"), "&Open CSV...", this);
    openAction->setShortcut(QKeySequence::Open);
    connect(openAction, &QAction::triggered, this, &MainWindow::openCsv);

    auto *saveAction = new QAction(QIcon::fromTheme("document-save"), "&Save CSV", this);
    saveAction->setShortcut(QKeySequence::Save);
    connect(saveAction, &QAction::triggered, this, &MainWindow::saveCsv);

    auto *saveAsAction = new QAction("Save CSV &As...", this);
    saveAsAction->setShortcut(QKeySequence::SaveAs);
    connect(saveAsAction, &QAction::triggered, this, &MainWindow::saveCsvAs);

    auto *quitAction = new QAction("&Quit", this);
    quitAction->setShortcut(QKeySequence::Quit);
    connect(quitAction, &QAction::triggered, this, &QWidget::close);

    fileMenu->addAction(newAction);
    fileMenu->addAction(openAction);
    fileMenu->addAction(saveAction);
    fileMenu->addAction(saveAsAction);
    recentFilesMenu_ = fileMenu->addMenu("Open &Recent");
    for (auto *&action : recentFileActions_) {
        action = new QAction(this);
        action->setVisible(false);
        connect(action, &QAction::triggered, this, &MainWindow::openRecentCsv);
        recentFilesMenu_->addAction(action);
    }
    fileMenu->addSeparator();
    fileMenu->addAction(quitAction);

    fileToolbar->addAction(newAction);
    fileToolbar->addAction(openAction);
    fileToolbar->addAction(saveAction);
}

void MainWindow::createEditActions()
{
    auto *editMenu = menuBar()->addMenu("&Edit");
    auto *editToolbar = addToolBar("Edit");
    editToolbar->setMovable(false);

    auto *cutAction = new QAction(QIcon::fromTheme("edit-cut"), "Cu&t", this);
    cutAction->setShortcut(QKeySequence::Cut);
    connect(cutAction, &QAction::triggered, controller_, &SpreadsheetController::cutSelectionToClipboard);

    auto *copyAction = new QAction(QIcon::fromTheme("edit-copy"), "&Copy", this);
    copyAction->setShortcut(QKeySequence::Copy);
    connect(copyAction, &QAction::triggered, controller_, &SpreadsheetController::copySelectionToClipboard);

    auto *pasteAction = new QAction(QIcon::fromTheme("edit-paste"), "&Paste", this);
    pasteAction->setShortcut(QKeySequence::Paste);
    connect(pasteAction, &QAction::triggered, controller_, &SpreadsheetController::pasteClipboard);

    editMenu->addAction(cutAction);
    editMenu->addAction(copyAction);
    editMenu->addAction(pasteAction);

    editToolbar->addAction(cutAction);
    editToolbar->addAction(copyAction);
    editToolbar->addAction(pasteAction);
}

void MainWindow::createFormulaActions()
{
    auto *formulaMenu = menuBar()->addMenu("F&ormula");
    auto *formulaToolbar = addToolBar("Formula");
    formulaToolbar->setMovable(false);

    auto *sumAction = new QAction(QIcon::fromTheme("list-add"), "&SUM", this);
    connect(sumAction, &QAction::triggered, this, [this]() {
        startFormula("SUM");
    });

    auto *averageAction = new QAction("&AVERAGE", this);
    connect(averageAction, &QAction::triggered, this, [this]() {
        startFormula("AVERAGE");
    });

    formulaMenu->addAction(sumAction);
    formulaMenu->addAction(averageAction);
    formulaToolbar->addAction(sumAction);
    formulaToolbar->addAction(averageAction);
}

void MainWindow::closeEvent(QCloseEvent *event)
{
    if (maybeSave()) {
        event->accept();
        return;
    }
    event->ignore();
}

void MainWindow::newWorkbook()
{
    if (!maybeSave()) {
        return;
    }
    controller_->newSheet();
    setCurrentFileName(QString());
    updateFormulaBarFromCurrentCell();
    statusBar()->showMessage("New workbook", 3000);
}

void MainWindow::openCsv()
{
    if (!maybeSave()) {
        return;
    }

    const QString fileName = QFileDialog::getOpenFileName(
        this,
        "Open CSV",
        QString(),
        "CSV Files (*.csv);;All Files (*)");
    if (fileName.isEmpty()) {
        return;
    }

    QString error;
    if (!controller_->openCsv(fileName, &error)) {
        showError("Open CSV Failed", error);
        return;
    }
    setCurrentFileName(fileName);
    addRecentFile(fileName);
    updateFormulaBarFromCurrentCell();
    statusBar()->showMessage("Opened " + fileName, 3000);
}

void MainWindow::openRecentCsv()
{
    auto *action = qobject_cast<QAction *>(sender());
    if (!action || !maybeSave()) {
        return;
    }

    const QString fileName = action->data().toString();
    QString error;
    if (!controller_->openCsv(fileName, &error)) {
        showError("Open CSV Failed", error);
        return;
    }
    setCurrentFileName(fileName);
    addRecentFile(fileName);
    updateFormulaBarFromCurrentCell();
    statusBar()->showMessage("Opened " + fileName, 3000);
}

void MainWindow::startFormula(const QString &functionName)
{
    formulaTargetRow_ = table_->currentRow();
    formulaTargetColumn_ = table_->currentColumn();
    if (formulaTargetRow_ < 0 || formulaTargetColumn_ < 0) {
        formulaTargetRow_ = 0;
        formulaTargetColumn_ = 0;
        table_->setCurrentCell(formulaTargetRow_, formulaTargetColumn_);
    }

    selectingFormulaReference_ = true;
    updatingFormulaBar_ = true;
    formulaBar_->setText("=" + functionName + "(");
    formulaBar_->setCursorPosition(formulaBar_->text().size());
    updatingFormulaBar_ = false;
    formulaBar_->setFocus();
}

void MainWindow::updateFormulaBarFromCurrentCell()
{
    if (updatingFormulaBar_) {
        return;
    }

    updatingFormulaBar_ = true;
    formulaBar_->setText(controller_->cellRawValue(table_->currentRow(), table_->currentColumn()));
    updatingFormulaBar_ = false;
}

void MainWindow::commitFormulaBar()
{
    const int row = formulaTargetRow_ >= 0 ? formulaTargetRow_ : table_->currentRow();
    const int column = formulaTargetColumn_ >= 0 ? formulaTargetColumn_ : table_->currentColumn();
    controller_->setCellRawValue(row, column, formulaBar_->text());
    table_->setCurrentCell(row, column);
    selectingFormulaReference_ = false;
    formulaTargetRow_ = -1;
    formulaTargetColumn_ = -1;
    updateFormulaBarFromCurrentCell();
}

void MainWindow::handleFormulaBarEdited(const QString &text)
{
    if (updatingFormulaBar_) {
        return;
    }

    if (formulaTargetRow_ < 0 || formulaTargetColumn_ < 0) {
        formulaTargetRow_ = table_->currentRow();
        formulaTargetColumn_ = table_->currentColumn();
    }
    selectingFormulaReference_ = text.trimmed().startsWith('=');
}

void MainWindow::insertSelectedReferenceIntoFormulaBar()
{
    if (!selectingFormulaReference_ || updatingFormulaBar_) {
        return;
    }

    const QString text = formulaBar_->text();
    const int openParenthesis = text.lastIndexOf('(');
    if (openParenthesis < 0 || text.indexOf(')', openParenthesis) >= 0) {
        return;
    }

    const QString reference = controller_->selectedRangeReference();
    if (reference.isEmpty()) {
        return;
    }

    updatingFormulaBar_ = true;
    formulaBar_->setText(text.left(openParenthesis + 1) + reference + ')');
    formulaBar_->setCursorPosition(formulaBar_->text().size());
    updatingFormulaBar_ = false;
    commitFormulaBar();
}

void MainWindow::saveCsv()
{
    if (!currentFileName_.isEmpty()) {
        saveCsvToFile(currentFileName_);
        return;
    }
    saveCsvAs();
}

void MainWindow::saveCsvAs()
{
    const QString fileName = QFileDialog::getSaveFileName(
        this,
        "Save CSV",
        currentFileName_,
        "CSV Files (*.csv);;All Files (*)");
    if (fileName.isEmpty()) {
        return;
    }

    saveCsvToFile(fileName);
}

bool MainWindow::maybeSave()
{
    if (!controller_->isModified()) {
        return true;
    }

    const QMessageBox::StandardButton choice = QMessageBox::warning(
        this,
        "Unsaved Changes",
        "Save changes to this workbook?",
        QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel,
        QMessageBox::Save);

    if (choice == QMessageBox::Save) {
        saveCsv();
        return !controller_->isModified();
    }
    return choice == QMessageBox::Discard;
}

bool MainWindow::saveCsvToFile(const QString &fileName)
{
    QString error;
    if (!controller_->saveCsv(fileName, &error)) {
        showError("Save CSV Failed", error);
        return false;
    }
    setCurrentFileName(fileName);
    addRecentFile(fileName);
    statusBar()->showMessage("Saved " + fileName, 3000);
    return true;
}

void MainWindow::setCurrentFileName(const QString &fileName)
{
    currentFileName_ = fileName;
    updateWindowTitle();
}

void MainWindow::addRecentFile(const QString &fileName)
{
    QStringList files = recentFiles();
    files.removeAll(fileName);
    files.prepend(fileName);
    while (files.size() > MaxRecentFiles) {
        files.removeLast();
    }

    QSettings settings;
    settings.setValue("recentFiles", files);
    updateRecentFileActions();
}

QStringList MainWindow::recentFiles() const
{
    return QSettings().value("recentFiles").toStringList();
}

void MainWindow::updateRecentFileActions()
{
    const QStringList files = recentFiles();
    const int count = std::min(static_cast<int>(files.size()), MaxRecentFiles);

    for (int index = 0; index < MaxRecentFiles; ++index) {
        QAction *action = recentFileActions_[index];
        if (index < count) {
            const QString fileName = files[index];
            action->setText(QString("&%1 %2").arg(index + 1).arg(QFileInfo(fileName).fileName()));
            action->setData(fileName);
            action->setStatusTip(fileName);
            action->setVisible(true);
        } else {
            action->setVisible(false);
        }
    }
    recentFilesMenu_->setEnabled(count > 0);
}

void MainWindow::updateWindowTitle()
{
    const QString name = currentFileName_.isEmpty()
        ? QString("Untitled")
        : QFileInfo(currentFileName_).fileName();
    setWindowTitle(name + "[*] - Retro Spreadsheet");
}

void MainWindow::showError(const QString &title, const QString &message)
{
    QMessageBox::critical(this, title, message);
}

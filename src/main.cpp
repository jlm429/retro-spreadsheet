#include "RetroSpreadsheet/MainWindow.h"

#include <QApplication>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("Retro Spreadsheet");
    QApplication::setOrganizationName("Retro Spreadsheet");

    MainWindow window;
    window.show();

    return app.exec();
}

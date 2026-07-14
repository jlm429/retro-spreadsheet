#import <AppKit/AppKit.h>

#include "RetroSpreadsheet/MainWindow.h"
#include "RetroSpreadsheet/Workbook.h"

#include <memory>

namespace {
NSString *asNSString(const std::string &value) { return [NSString stringWithUTF8String:value.c_str()]; }
std::string asString(NSString *value) { return value ? std::string(value.UTF8String ?: "") : std::string(); }
void requireMainThread() { NSCAssert(NSThread.isMainThread, @"Workbook UI access must stay on the main thread."); }
NSString *columnName(NSInteger column) { return [NSString stringWithFormat:@"%c", static_cast<int>('A' + column)]; }
}

@class WorkbookDocument;
@class SpreadsheetWindowController;

@interface SpreadsheetTableView : NSTableView
@property(nonatomic, assign) SpreadsheetWindowController *spreadsheetController;
@end

@interface SpreadsheetCellTextField : NSTextField
@property(nonatomic, assign) SpreadsheetWindowController *spreadsheetController;
@property(nonatomic) NSInteger spreadsheetRow;
@property(nonatomic) NSInteger spreadsheetColumn;
@end

@interface SpreadsheetWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
- (instancetype)initWithDocument:(WorkbookDocument *)document;
- (IBAction)copy:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)insertSum:(id)sender;
- (IBAction)insertAverage:(id)sender;
- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)column;
@end

@implementation SpreadsheetTableView

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    const NSInteger row = [self rowAtPoint:point];
    const NSInteger column = [self columnAtPoint:point];
    if (row >= 0 && column >= 0) [self.spreadsheetController selectCellAtRow:row column:column];
    [super mouseDown:event];
}
@end

@implementation SpreadsheetCellTextField

- (void)mouseDown:(NSEvent *)event
{
    [self.spreadsheetController selectCellAtRow:_spreadsheetRow column:_spreadsheetColumn];
    [super mouseDown:event];
}
@end

@interface WorkbookDocument : NSDocument
{
    std::unique_ptr<Workbook> _workbook;
    NSOperationQueue *_operationQueue;
}
- (Workbook *)workbook;
- (void)workbookDidChange;
// Future background results must call this on the main thread before applying.
- (BOOL)canApplyResultForRevision:(std::uint64_t)revision;
@end

@implementation WorkbookDocument

- (instancetype)init
{
    self = [super init];
    if (self) {
        _workbook = std::make_unique<Workbook>();
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.name = @"com.jlm429.retrospreadsheet.document-operations";
        _operationQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (void)dealloc
{
    _workbook->cancelOperations();
    [_operationQueue cancelAllOperations];
    [_operationQueue release];
    [super dealloc];
}

- (Workbook *)workbook { requireMainThread(); return _workbook.get(); }

- (BOOL)canApplyResultForRevision:(std::uint64_t)revision
{
    requireMainThread();
    return _workbook->isCurrentRevision(revision);
}

- (void)makeWindowControllers
{
    requireMainThread();
    [self addWindowController:[[SpreadsheetWindowController alloc] initWithDocument:self]];
}

- (NSString *)windowNibName { return nil; }

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    requireMainThread();
    std::string error;
    if (_workbook->loadCsv(asString(url.path), &error)) return YES;
    if (outError) *outError = [NSError errorWithDomain:@"RetroSpreadsheet" code:1 userInfo:@{NSLocalizedDescriptionKey: asNSString(error)}];
    return NO;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
    requireMainThread();
    std::string error;
    if (_workbook->saveCsv(asString(url.path), &error)) return YES;
    if (outError) *outError = [NSError errorWithDomain:@"RetroSpreadsheet" code:2 userInfo:@{NSLocalizedDescriptionKey: asNSString(error)}];
    return NO;
}

- (void)workbookDidChange
{
    requireMainThread();
    [self updateChangeCount:NSChangeDone];
}
@end

@interface SpreadsheetWindowController ()
@property(nonatomic, assign) WorkbookDocument *workbookDocument;
@property(nonatomic, strong) NSTableView *table;
@property(nonatomic, strong) NSTextField *formulaBar;
@property(nonatomic, strong) NSTextField *statusField;
@property(nonatomic) BOOL updatingFormulaBar;
@property(nonatomic) NSInteger activeRow;
@property(nonatomic) NSInteger activeColumn;
@end

@implementation SpreadsheetWindowController

- (instancetype)initWithDocument:(WorkbookDocument *)document
{
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1060, 650)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _workbookDocument = document;
        window.titleVisibility = NSWindowTitleVisible;
        window.minSize = NSMakeSize(700, 420);
        [self buildInterface];
    }
    return self;
}

- (void)buildInterface
{
    NSView *content = self.window.contentView;
    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor], [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
    ]];

    NSView *formulaRow = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 42)];
    NSTextField *fx = [NSTextField labelWithString:@"fx"];
    fx.font = [NSFont boldSystemFontOfSize:14]; fx.alignment = NSTextAlignmentCenter; fx.translatesAutoresizingMaskIntoConstraints = NO;
    _formulaBar = [[NSTextField alloc] init];
    _formulaBar.placeholderString = @"Enter a value or formula"; _formulaBar.delegate = self; _formulaBar.translatesAutoresizingMaskIntoConstraints = NO;
    [formulaRow addSubview:fx]; [formulaRow addSubview:_formulaBar];
    [NSLayoutConstraint activateConstraints:@[
        [formulaRow.heightAnchor constraintEqualToConstant:42], [fx.leadingAnchor constraintEqualToAnchor:formulaRow.leadingAnchor constant:12],
        [fx.widthAnchor constraintEqualToConstant:32], [fx.centerYAnchor constraintEqualToAnchor:formulaRow.centerYAnchor],
        [_formulaBar.leadingAnchor constraintEqualToAnchor:fx.trailingAnchor constant:8], [_formulaBar.trailingAnchor constraintEqualToAnchor:formulaRow.trailingAnchor constant:-12],
        [_formulaBar.centerYAnchor constraintEqualToAnchor:formulaRow.centerYAnchor]
    ]];
    [stack addArrangedSubview:formulaRow];

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES; scroll.hasHorizontalScroller = YES; scroll.borderType = NSBezelBorder;
    _table = [[SpreadsheetTableView alloc] init];
    static_cast<SpreadsheetTableView *>(_table).spreadsheetController = self;
    _table.dataSource = self; _table.delegate = self; _table.allowsMultipleSelection = NO; _table.allowsEmptySelection = NO;
    _table.allowsColumnSelection = NO; _table.usesAlternatingRowBackgroundColors = YES; _table.rowHeight = 25;
    for (NSInteger column = 0; column < Workbook::ColumnCount; ++column) {
        NSTableColumn *tableColumn = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%ld", static_cast<long>(column)]];
        tableColumn.title = columnName(column); tableColumn.width = 102; tableColumn.minWidth = 72; tableColumn.editable = YES;
        [_table addTableColumn:tableColumn];
    }
    scroll.documentView = _table;
    [stack addArrangedSubview:scroll];

    NSView *statusRow = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 26)];
    _statusField = [NSTextField labelWithString:@"Ready"];
    _statusField.font = [NSFont systemFontOfSize:12]; _statusField.textColor = NSColor.secondaryLabelColor; _statusField.translatesAutoresizingMaskIntoConstraints = NO;
    [statusRow addSubview:_statusField];
    [NSLayoutConstraint activateConstraints:@[[statusRow.heightAnchor constraintEqualToConstant:26], [_statusField.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor constant:12], [_statusField.centerYAnchor constraintEqualToAnchor:statusRow.centerYAnchor]]];
    [stack addArrangedSubview:statusRow];
    _activeRow = 0;
    _activeColumn = 0;
    [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:_activeRow] byExtendingSelection:NO];
    [self updateFormulaBar];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return Workbook::RowCount; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    SpreadsheetCellTextField *cell = [tableView makeViewWithIdentifier:@"SpreadsheetCell" owner:self];
    if (!cell) {
        cell = [[SpreadsheetCellTextField alloc] init]; cell.identifier = @"SpreadsheetCell"; cell.bordered = NO; cell.backgroundColor = NSColor.clearColor;
        cell.lineBreakMode = NSLineBreakByTruncatingTail; cell.editable = YES; cell.selectable = YES;
    }
    cell.spreadsheetController = self;
    cell.spreadsheetRow = row;
    cell.spreadsheetColumn = column.identifier.integerValue;
    cell.stringValue = asNSString([self.workbookDocument workbook]->displayValue(static_cast<int>(row), column.identifier.integerValue));
    return cell;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    return asNSString([self.workbookDocument workbook]->rawValue(static_cast<int>(row), column.identifier.integerValue));
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    [self selectCellAtRow:row column:column.identifier.integerValue];
    Workbook *workbook = self.workbookDocument.workbook;
    workbook->setRawValue(static_cast<int>(row), column.identifier.integerValue, asString(object));
    [self.workbookDocument workbookDidChange]; [tableView reloadData]; [self updateFormulaBar];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (_table.selectedRow >= 0) _activeRow = _table.selectedRow;
    [self updateFormulaBar];
}
- (void)controlTextDidEndEditing:(NSNotification *)notification { if (notification.object == _formulaBar) [self commitFormulaBar]; }

- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)column
{
    if (row < 0 || row >= Workbook::RowCount || column < 0 || column >= Workbook::ColumnCount) return;
    _activeRow = row;
    _activeColumn = column;
    if (_table.selectedRow != row) [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self updateFormulaBar];
}

- (void)updateFormulaBar
{
    if (_updatingFormulaBar || _activeRow < 0 || _activeColumn < 0) return;
    _updatingFormulaBar = YES;
    _formulaBar.stringValue = asNSString([self.workbookDocument workbook]->rawValue(static_cast<int>(_activeRow), static_cast<int>(_activeColumn)));
    _statusField.stringValue = [NSString stringWithFormat:@"%@%ld", columnName(_activeColumn), static_cast<long>(_activeRow + 1)];
    _updatingFormulaBar = NO;
}

- (void)commitFormulaBar
{
    if (_activeRow < 0 || _activeColumn < 0) return;
    [self.workbookDocument workbook]->setRawValue(static_cast<int>(_activeRow), static_cast<int>(_activeColumn), asString(_formulaBar.stringValue));
    [self.workbookDocument workbookDidChange]; [_table reloadData]; [self updateFormulaBar];
}

- (void)selectedRangeFirstRow:(NSInteger *)firstRow firstColumn:(NSInteger *)firstColumn lastRow:(NSInteger *)lastRow lastColumn:(NSInteger *)lastColumn
{
    *firstRow = _activeRow;
    *lastRow = _activeRow;
    *firstColumn = _activeColumn;
    *lastColumn = _activeColumn;
}

- (IBAction)copy:(id)sender
{
    NSInteger firstRow, firstColumn, lastRow, lastColumn;
    [self selectedRangeFirstRow:&firstRow firstColumn:&firstColumn lastRow:&lastRow lastColumn:&lastColumn];
    if (firstRow < 0 || firstColumn < 0) return;
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:asNSString([self.workbookDocument workbook]->selectionText(static_cast<int>(firstRow), static_cast<int>(firstColumn), static_cast<int>(lastRow), static_cast<int>(lastColumn))) forType:NSPasteboardTypeString];
}

- (IBAction)cut:(id)sender
{
    [self copy:sender];
    NSInteger firstRow, firstColumn, lastRow, lastColumn;
    [self selectedRangeFirstRow:&firstRow firstColumn:&firstColumn lastRow:&lastRow lastColumn:&lastColumn];
    [self.workbookDocument workbook]->clearRange(static_cast<int>(firstRow), static_cast<int>(firstColumn), static_cast<int>(lastRow), static_cast<int>(lastColumn));
    [self.workbookDocument workbookDidChange]; [_table reloadData]; [self updateFormulaBar];
}

- (IBAction)paste:(id)sender
{
    NSString *text = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
    if (!text || _activeRow < 0 || _activeColumn < 0) return;
    [self.workbookDocument workbook]->pasteText(static_cast<int>(_activeRow), static_cast<int>(_activeColumn), asString(text));
    [self.workbookDocument workbookDidChange]; [_table reloadData]; [self updateFormulaBar];
}

- (IBAction)insertSum:(id)sender { [self beginFormula:@"=SUM("]; }
- (IBAction)insertAverage:(id)sender { [self beginFormula:@"=AVERAGE("]; }
- (void)beginFormula:(NSString *)prefix { _formulaBar.stringValue = prefix; [self.window makeFirstResponder:_formulaBar]; }
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender { return YES; }
@end

static NSMenuItem *menuItem(NSString *title, SEL action, NSString *key)
{
    return [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key ?: @""];
}

static void buildMenus()
{
    NSMenu *main = [[NSMenu alloc] initWithTitle:@"Main"];
    NSMenuItem *appItem = menuItem(@"Retro Spreadsheet", nil, nil); NSMenu *app = [[NSMenu alloc] initWithTitle:@"Retro Spreadsheet"];
    [app addItem:menuItem(@"About Retro Spreadsheet", @selector(orderFrontStandardAboutPanel:), @"")]; [app addItem:NSMenuItem.separatorItem]; [app addItem:menuItem(@"Quit Retro Spreadsheet", @selector(terminate:), @"q")]; appItem.submenu = app; [main addItem:appItem];
    NSMenuItem *fileItem = menuItem(@"File", nil, nil); NSMenu *file = [[NSMenu alloc] initWithTitle:@"File"];
    [file addItem:menuItem(@"New", @selector(newDocument:), @"n")]; [file addItem:menuItem(@"Open…", @selector(openDocument:), @"o")]; [file addItem:NSMenuItem.separatorItem]; [file addItem:menuItem(@"Save", @selector(saveDocument:), @"s")]; [file addItem:menuItem(@"Save As…", @selector(saveDocumentAs:), @"S")]; [file addItem:NSMenuItem.separatorItem]; [file addItem:menuItem(@"Close", @selector(performClose:), @"w")]; fileItem.submenu = file; [main addItem:fileItem];
    NSMenuItem *editItem = menuItem(@"Edit", nil, nil); NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    [edit addItem:menuItem(@"Cut", @selector(cut:), @"x")]; [edit addItem:menuItem(@"Copy", @selector(copy:), @"c")]; [edit addItem:menuItem(@"Paste", @selector(paste:), @"v")]; editItem.submenu = edit; [main addItem:editItem];
    NSMenuItem *formulaItem = menuItem(@"Formula", nil, nil); NSMenu *formula = [[NSMenu alloc] initWithTitle:@"Formula"];
    [formula addItem:menuItem(@"SUM", @selector(insertSum:), @"")]; [formula addItem:menuItem(@"AVERAGE", @selector(insertAverage:), @"")]; formulaItem.submenu = formula; [main addItem:formulaItem];
    NSApp.mainMenu = main;
}

int runRetroSpreadsheetApplication(int argc, const char *argv[])
{
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        buildMenus();
        AppDelegate *delegate = [[AppDelegate alloc] init]; application.delegate = delegate;
        [application activateIgnoringOtherApps:YES];
        return NSApplicationMain(argc, argv);
    }
}

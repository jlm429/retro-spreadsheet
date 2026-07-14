#import <AppKit/AppKit.h>

#include "RetroSpreadsheet/MainWindow.h"
#include "RetroSpreadsheet/FormulaEditingSession.h"
#include "RetroSpreadsheet/Workbook.h"

#include <memory>
#include <cstdlib>

namespace {
NSString *asNSString(const std::string &value) { return [NSString stringWithUTF8String:value.c_str()]; }
std::string asString(NSString *value)
{
    const char *utf8Value = value.UTF8String;
    return utf8Value ? std::string(utf8Value) : std::string();
}
void requireMainThread() { NSCAssert(NSThread.isMainThread, @"Workbook UI access must stay on the main thread."); }
NSString *columnName(NSInteger column) { return [NSString stringWithFormat:@"%c", static_cast<int>('A' + column)]; }
NSWindow *frontWindow() { return NSApp.keyWindow ? NSApp.keyWindow : NSApp.windows.firstObject; }
bool uiSmokeTestMode = false;
bool uiSmokeTestFailed = false;

NSTableView *findTableView(NSView *view)
{
    if ([view isKindOfClass:NSTableView.class]) return static_cast<NSTableView *>(view);
    for (NSView *subview in view.subviews) if (NSTableView *table = findTableView(subview)) return table;
    return nil;
}

void writeUiSmokeDiagnostics(NSString *message)
{
    const char *directory = std::getenv("RETRO_SPREADSHEET_UI_ARTIFACTS");
    if (!directory) { NSLog(@"UI smoke test failure: %@", message); return; }
    NSString *path = [NSString stringWithUTF8String:directory];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    [message writeToFile:[path stringByAppendingPathComponent:@"failure.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString *diagnostics = [NSString stringWithFormat:@"%@\n\nWindow hierarchy:\n%@\n", message, NSApp.windows];
    [diagnostics writeToFile:[path stringByAppendingPathComponent:@"diagnostics.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSWindow *window = frontWindow();
    if (window) {
        NSView *content = window.contentView;
        NSBitmapImageRep *image = [content bitmapImageRepForCachingDisplayInRect:content.bounds];
        [content cacheDisplayInRect:content.bounds toBitmapImageRep:image];
        [[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[path stringByAppendingPathComponent:@"failure.png"] atomically:YES];
    }
    NSLog(@"UI smoke test failure: %@", message);
}

void writeUiSmokeSuccess()
{
    const char *directory = std::getenv("RETRO_SPREADSHEET_UI_ARTIFACTS");
    if (!directory) return;
    NSString *path = [NSString stringWithUTF8String:directory];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    [@"PASS\n" writeToFile:[path stringByAppendingPathComponent:@"success.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
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

@interface FormulaBarTextField : NSTextField
@property(nonatomic, assign) SpreadsheetWindowController *spreadsheetController;
@end

@interface SpreadsheetWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
{
    std::unique_ptr<FormulaEditingSession> _formulaSession;
}
- (instancetype)initWithDocument:(WorkbookDocument *)document;
- (IBAction)copy:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)insertSum:(id)sender;
- (IBAction)insertAverage:(id)sender;
- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)column;
- (void)handleCellMouseDownAtRow:(NSInteger)row column:(NSInteger)column event:(NSEvent *)event;
- (void)cancelFormulaBar;
- (BOOL)isFormulaEditing;
- (BOOL)isReferenceCellAtRow:(NSInteger)row column:(NSInteger)column;
@end

@implementation SpreadsheetTableView

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    const NSInteger row = [self rowAtPoint:point];
    const NSInteger column = [self columnAtPoint:point];
    if (row >= 0 && column >= 0) [self.spreadsheetController handleCellMouseDownAtRow:row column:column event:event];
    if ([self.spreadsheetController isFormulaEditing]) return;
    [super mouseDown:event];
}
@end

@implementation SpreadsheetCellTextField

- (void)mouseDown:(NSEvent *)event
{
    [self.spreadsheetController handleCellMouseDownAtRow:_spreadsheetRow column:_spreadsheetColumn event:event];
    if (![self.spreadsheetController isReferenceCellAtRow:_spreadsheetRow column:_spreadsheetColumn]) [super mouseDown:event];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    if ([self.spreadsheetController isReferenceCellAtRow:_spreadsheetRow column:_spreadsheetColumn]) {
        [NSColor.systemOrangeColor setStroke];
        NSFrameRectWithWidth(self.bounds, 2.0);
    }
}
@end

@implementation FormulaBarTextField
- (void)keyDown:(NSEvent *)event
{
    if (event.keyCode == 53) { [self.spreadsheetController cancelFormulaBar]; return; }
    [super keyDown:event];
}
@end

@interface WorkbookDocument : NSDocument
{
    std::unique_ptr<Workbook> _workbook;
}
- (Workbook *)workbook;
- (void)workbookDidChange;
@end

@implementation WorkbookDocument

- (instancetype)init
{
    self = [super init];
    if (self) {
        _workbook = std::make_unique<Workbook>();
    }
    return self;
}

- (Workbook *)workbook { requireMainThread(); return _workbook.get(); }

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
@property(nonatomic, strong) FormulaBarTextField *formulaBar;
@property(nonatomic, strong) NSTextField *statusField;
@property(nonatomic, strong) NSPopUpButton *fontFamilyControl;
@property(nonatomic, strong) NSPopUpButton *fontSizeControl;
@property(nonatomic, strong) NSSegmentedControl *styleControl;
@property(nonatomic, strong) NSSegmentedControl *alignmentControl;
@property(nonatomic) BOOL updatingFormulaBar;
@property(nonatomic) BOOL discardingFormulaEdit;
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
        _formulaSession = std::make_unique<FormulaEditingSession>();
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

    NSView *ribbon = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 34)];
    ribbon.wantsLayer = YES;
    ribbon.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
    _fontFamilyControl = [[NSPopUpButton alloc] init];
    [_fontFamilyControl addItemsWithTitles:@[@"Helvetica", @"Times-Roman", @"Courier"]];
    _fontFamilyControl.target = self; _fontFamilyControl.action = @selector(changeFontFamily:); _fontFamilyControl.translatesAutoresizingMaskIntoConstraints = NO;
    _fontSizeControl = [[NSPopUpButton alloc] init];
    [_fontSizeControl addItemsWithTitles:@[@"10", @"12", @"14", @"18", @"24"]];
    _fontSizeControl.target = self; _fontSizeControl.action = @selector(changeFontSize:); _fontSizeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _styleControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
    _styleControl.segmentCount = 3; [_styleControl setLabel:@"B" forSegment:0]; [_styleControl setLabel:@"I" forSegment:1]; [_styleControl setLabel:@"U" forSegment:2];
    _styleControl.trackingMode = NSSegmentSwitchTrackingSelectAny; _styleControl.target = self; _styleControl.action = @selector(changeStyle:); _styleControl.segmentStyle = NSSegmentStyleSmallSquare; _styleControl.translatesAutoresizingMaskIntoConstraints = NO;
    _alignmentControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
    _alignmentControl.segmentCount = 3; [_alignmentControl setLabel:@"Left" forSegment:0]; [_alignmentControl setLabel:@"Center" forSegment:1]; [_alignmentControl setLabel:@"Right" forSegment:2];
    _alignmentControl.trackingMode = NSSegmentSwitchTrackingSelectOne; _alignmentControl.target = self; _alignmentControl.action = @selector(changeAlignment:); _alignmentControl.segmentStyle = NSSegmentStyleSmallSquare; _alignmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    NSPopUpButton *functions = [[NSPopUpButton alloc] init];
    [functions addItemsWithTitles:@[@"Functions", @"SUM", @"AVERAGE", @"MIN", @"MAX", @"COUNT"]];
    functions.target = self; functions.action = @selector(insertFunction:); functions.translatesAutoresizingMaskIntoConstraints = NO;
    [ribbon addSubview:_fontFamilyControl]; [ribbon addSubview:_fontSizeControl]; [ribbon addSubview:_styleControl]; [ribbon addSubview:_alignmentControl]; [ribbon addSubview:functions];
    [NSLayoutConstraint activateConstraints:@[
        [ribbon.heightAnchor constraintEqualToConstant:34], [_fontFamilyControl.leadingAnchor constraintEqualToAnchor:ribbon.leadingAnchor constant:10], [_fontFamilyControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_fontSizeControl.leadingAnchor constraintEqualToAnchor:_fontFamilyControl.trailingAnchor constant:6], [_fontSizeControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_styleControl.leadingAnchor constraintEqualToAnchor:_fontSizeControl.trailingAnchor constant:10], [_styleControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_alignmentControl.leadingAnchor constraintEqualToAnchor:_styleControl.trailingAnchor constant:10], [_alignmentControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [functions.leadingAnchor constraintEqualToAnchor:_alignmentControl.trailingAnchor constant:10], [functions.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor]
    ]];
    [stack addArrangedSubview:ribbon];

    NSView *formulaRow = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 38)];
    NSTextField *fx = [NSTextField labelWithString:@"fx"];
    fx.font = [NSFont boldSystemFontOfSize:14]; fx.alignment = NSTextAlignmentCenter; fx.translatesAutoresizingMaskIntoConstraints = NO;
    _formulaBar = [[FormulaBarTextField alloc] init];
    _formulaBar.spreadsheetController = self;
    _formulaBar.placeholderString = @"Enter a value or formula"; _formulaBar.delegate = self; _formulaBar.translatesAutoresizingMaskIntoConstraints = NO;
    [formulaRow addSubview:fx]; [formulaRow addSubview:_formulaBar];
    [NSLayoutConstraint activateConstraints:@[
        [formulaRow.heightAnchor constraintEqualToConstant:38], [fx.leadingAnchor constraintEqualToAnchor:formulaRow.leadingAnchor constant:12],
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
    const CellFormat format = [self.workbookDocument workbook]->cellFormat(static_cast<int>(row), column.identifier.integerValue);
    NSFont *font = [NSFont fontWithName:asNSString(format.fontFamily) size:format.fontSize];
    if (!font) font = [NSFont systemFontOfSize:format.fontSize];
    NSFontTraitMask traits = 0;
    if (format.bold) traits |= NSBoldFontMask;
    if (format.italic) traits |= NSItalicFontMask;
    if (traits) font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:traits];
    cell.font = font;
    cell.alignment = format.alignment == HorizontalAlignment::Center ? NSTextAlignmentCenter : format.alignment == HorizontalAlignment::Right ? NSTextAlignmentRight : NSTextAlignmentLeft;
    if (format.underline) cell.attributedStringValue = [[NSAttributedString alloc] initWithString:cell.stringValue attributes:@{NSFontAttributeName: font, NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)}];
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
    if (workbook->setRawValue(static_cast<int>(row), column.identifier.integerValue, asString(object))) {
        [self.workbookDocument workbookDidChange];
        [tableView reloadData];
        [self updateFormulaBar];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (_table.selectedRow >= 0) _activeRow = _table.selectedRow;
    [self updateFormulaBar];
}
- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
    if (notification.object == _formulaBar && !_formulaSession->isEditing()) {
        _formulaSession->begin({static_cast<int>(_activeRow), static_cast<int>(_activeColumn)}, asString(_formulaBar.stringValue));
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if (notification.object == _formulaBar && _formulaSession->isEditing()) _formulaSession->setDraft(asString(_formulaBar.stringValue));
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (control == _formulaBar && commandSelector == @selector(cancelOperation:)) {
        [self cancelFormulaBar];
        return YES;
    }
    return NO;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if (notification.object != _formulaBar) return;
    if (_discardingFormulaEdit) { _discardingFormulaEdit = NO; return; }
    [self commitFormulaBar];
}

- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)column
{
    if (row < 0 || row >= Workbook::RowCount || column < 0 || column >= Workbook::ColumnCount) return;
    _activeRow = row;
    _activeColumn = column;
    if (_table.selectedRow != row) [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self updateFormulaBar];
}

- (void)handleCellMouseDownAtRow:(NSInteger)row column:(NSInteger)column event:(NSEvent *)event
{
    if (!_formulaSession->isEditing()) { [self selectCellAtRow:row column:column]; return; }
    FormulaEditingSession::Range range{{static_cast<int>(row), static_cast<int>(column)}, {static_cast<int>(row), static_cast<int>(column)}};
    NSEvent *next = event;
    while (next.type != NSEventTypeLeftMouseUp) {
        next = [self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp untilDate:NSDate.distantFuture inMode:NSEventTrackingRunLoopMode dequeue:YES];
        if (!next) break;
        NSPoint point = [_table convertPoint:next.locationInWindow fromView:nil];
        const NSInteger draggedRow = [_table rowAtPoint:point];
        const NSInteger draggedColumn = [_table columnAtPoint:point];
        if (draggedRow >= 0 && draggedColumn >= 0) {
            range.last = {static_cast<int>(draggedRow), static_cast<int>(draggedColumn)};
            _formulaSession->setReferenceRange(range);
            [_table reloadData];
        }
    }
    _formulaSession->insertReference(range, _formulaSession->draft().size());
    _formulaBar.stringValue = asNSString(_formulaSession->draft());
    NSTextView *editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    editor.selectedRange = NSMakeRange(_formulaBar.stringValue.length, 0);
    [self.window makeFirstResponder:_formulaBar];
    [_table reloadData];
}

- (BOOL)isReferenceCellAtRow:(NSInteger)row column:(NSInteger)column
{
    if (!_formulaSession->isEditing()) return NO;
    const FormulaEditingSession::Range range = _formulaSession->referenceRange();
    return row >= std::min(range.first.row, range.last.row) && row <= std::max(range.first.row, range.last.row)
        && column >= std::min(range.first.column, range.last.column) && column <= std::max(range.first.column, range.last.column);
}

- (BOOL)isFormulaEditing { return _formulaSession->isEditing(); }

- (void)updateFormulaBar
{
    if (_updatingFormulaBar || _formulaSession->isEditing() || _activeRow < 0 || _activeColumn < 0) return;
    _updatingFormulaBar = YES;
    _formulaBar.stringValue = asNSString([self.workbookDocument workbook]->rawValue(static_cast<int>(_activeRow), static_cast<int>(_activeColumn)));
    _statusField.stringValue = [NSString stringWithFormat:@"%@%ld", columnName(_activeColumn), static_cast<long>(_activeRow + 1)];
    _updatingFormulaBar = NO;
    [self updateRibbonControls];
}

- (void)commitFormulaBar
{
    if (_activeRow < 0 || _activeColumn < 0) return;
    const BOOL completedFormulaSession = _formulaSession->isEditing();
    const FormulaEditingSession::Cell destination = completedFormulaSession
        ? _formulaSession->destination() : FormulaEditingSession::Cell{static_cast<int>(_activeRow), static_cast<int>(_activeColumn)};
    const std::string value = completedFormulaSession ? _formulaSession->commit() : asString(_formulaBar.stringValue);
    _formulaBar.stringValue = asNSString(value);
    _activeRow = destination.row;
    _activeColumn = destination.column;
    if ([self.workbookDocument workbook]->setRawValue(destination.row, destination.column, value)) {
        [self.workbookDocument workbookDidChange];
        [_table reloadData];
        [self updateFormulaBar];
    } else if (completedFormulaSession) {
        [_table reloadData];
        [self updateFormulaBar];
    }
}

- (void)cancelFormulaBar
{
    if (!_formulaSession->isEditing()) return;
    _discardingFormulaEdit = YES;
    _formulaBar.stringValue = asNSString(_formulaSession->cancel());
    [_table reloadData];
    [self.window makeFirstResponder:_table];
    [self updateFormulaBar];
}

- (void)updateRibbonControls
{
    if (_activeRow < 0 || _activeColumn < 0) return;
    const CellFormat format = [self.workbookDocument workbook]->cellFormat(static_cast<int>(_activeRow), static_cast<int>(_activeColumn));
    [_fontFamilyControl selectItemWithTitle:asNSString(format.fontFamily)];
    [_fontSizeControl selectItemWithTitle:[NSString stringWithFormat:@"%.0f", format.fontSize]];
    [_styleControl setSelected:format.bold forSegment:0]; [_styleControl setSelected:format.italic forSegment:1]; [_styleControl setSelected:format.underline forSegment:2];
    [_alignmentControl setSelected:YES forSegment:format.alignment == HorizontalAlignment::Left ? 0 : format.alignment == HorizontalAlignment::Center ? 1 : 2];
}

- (void)applyFormat:(const CellFormat &)format
{
    if ([self.workbookDocument workbook]->setCellFormat(static_cast<int>(_activeRow), static_cast<int>(_activeColumn), format)) {
        [self.workbookDocument workbookDidChange];
        [_table reloadData];
    }
}

- (IBAction)changeFontFamily:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.fontFamily = asString(_fontFamilyControl.titleOfSelectedItem); [self applyFormat:format]; }
- (IBAction)changeFontSize:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.fontSize = _fontSizeControl.titleOfSelectedItem.doubleValue; [self applyFormat:format]; }
- (IBAction)changeStyle:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.bold = [_styleControl isSelectedForSegment:0]; format.italic = [_styleControl isSelectedForSegment:1]; format.underline = [_styleControl isSelectedForSegment:2]; [self applyFormat:format]; }
- (IBAction)changeAlignment:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.alignment = _alignmentControl.selectedSegment == 1 ? HorizontalAlignment::Center : _alignmentControl.selectedSegment == 2 ? HorizontalAlignment::Right : HorizontalAlignment::Left; [self applyFormat:format]; }

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
    if ([self.workbookDocument workbook]->clearRange(static_cast<int>(firstRow), static_cast<int>(firstColumn), static_cast<int>(lastRow), static_cast<int>(lastColumn))) {
        [self.workbookDocument workbookDidChange];
        [_table reloadData];
        [self updateFormulaBar];
    }
}

- (IBAction)paste:(id)sender
{
    NSString *text = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
    if (!text || _activeRow < 0 || _activeColumn < 0) return;
    if ([self.workbookDocument workbook]->pasteText(static_cast<int>(_activeRow), static_cast<int>(_activeColumn), asString(text))) {
        [self.workbookDocument workbookDidChange];
        [_table reloadData];
        [self updateFormulaBar];
    }
}

- (IBAction)insertSum:(id)sender { [self beginFunction:@"SUM"]; }
- (IBAction)insertAverage:(id)sender { [self beginFunction:@"AVERAGE"]; }
- (IBAction)insertFunction:(id)sender
{
    NSString *function = static_cast<NSPopUpButton *>(sender).titleOfSelectedItem;
    if ([function isEqualToString:@"Functions"]) return;
    [self beginFunction:function];
    [static_cast<NSPopUpButton *>(sender) selectItemAtIndex:0];
}

- (void)beginFunction:(NSString *)function
{
    const FormulaEditingSession::Cell destination{static_cast<int>(_activeRow), static_cast<int>(_activeColumn)};
    _formulaSession->beginFunction(destination, [self.workbookDocument workbook]->rawValue(destination.row, destination.column), asString(function));
    _formulaBar.stringValue = asNSString(_formulaSession->draft());
    [self.window makeFirstResponder:_formulaBar];
    NSTextView *editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    editor.selectedRange = NSMakeRange(_formulaBar.stringValue.length, 0);
    _statusField.stringValue = [NSString stringWithFormat:@"Editing %@", asNSString(FormulaEditingSession::referenceText({destination, destination}))];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSDate *uiSmokeDeadline;
- (void)runUiSmokeCheck;
@end

@implementation AppDelegate
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender { return YES; }

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    if (!uiSmokeTestMode) return;
    self.uiSmokeDeadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    dispatch_async(dispatch_get_main_queue(), ^{ [self runUiSmokeCheck]; });
}

- (void)runUiSmokeCheck
{
    NSWindow *window = frontWindow();
    NSTableView *table = window ? findTableView(window.contentView) : nil;
    if (window.visible && !table.hidden) {
        [window makeKeyAndOrderFront:nil];
        [table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        if (table.selectedRow != 0 || table.tableColumns.count == 0) {
            uiSmokeTestFailed = true;
            writeUiSmokeDiagnostics(@"FAIL:\nCould not select the first spreadsheet cell within 2 seconds.\nExpected an editable grid with cell A1 selected.");
        } else {
            NSTableColumn *column = table.tableColumns.firstObject;
            [table.dataSource tableView:table setObjectValue:@"UI smoke value" forTableColumn:column row:0];
            [table reloadData];
            NSView *cell = [table viewAtColumn:0 row:0 makeIfNecessary:YES];
            if (![cell isKindOfClass:NSTextField.class] || ![static_cast<NSTextField *>(cell).stringValue isEqualToString:@"UI smoke value"]) {
                uiSmokeTestFailed = true;
                writeUiSmokeDiagnostics(@"FAIL:\nBasic editing of A1 did not complete within 2 seconds.\nExpected the visible spreadsheet cell to display the entered value.");
            }
        }
        if (!uiSmokeTestFailed) writeUiSmokeSuccess();
        for (NSDocument *document in NSDocumentController.sharedDocumentController.documents) {
            [document updateChangeCount:NSChangeCleared];
        }
        [NSApp terminate:nil];
        return;
    }
    if (self.uiSmokeDeadline.timeIntervalSinceNow <= 0.0) {
        uiSmokeTestFailed = true;
        writeUiSmokeDiagnostics(@"FAIL:\nMain window did not appear within 5 seconds.\nExpected visible spreadsheet window.\nObserved application launched but no visible grid became available.");
        [NSApp terminate:nil];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self runUiSmokeCheck]; });
}
@end

static NSMenuItem *menuItem(NSString *title, SEL action, NSString *key)
{
    return [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key ? key : @""];
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
    for (int index = 1; index < argc; ++index) if (std::string(argv[index]) == "--ui-smoke-test") uiSmokeTestMode = true;
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        buildMenus();
        AppDelegate *delegate = [[AppDelegate alloc] init]; application.delegate = delegate;
        [application activateIgnoringOtherApps:YES];
        NSApplicationMain(argc, argv);
        return uiSmokeTestFailed ? EXIT_FAILURE : EXIT_SUCCESS;
    }
}

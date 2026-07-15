#import <AppKit/AppKit.h>

#include "RetroSpreadsheet/MainWindow.h"
#include "RetroSpreadsheet/FormulaEditingSession.h"
#include "RetroSpreadsheet/SelectionModel.h"
#include "RetroSpreadsheet/Workbook.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <memory>

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
bool uiEndToEndTestMode = false;
bool uiSmokeTestFailed = false;

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
    NSWindow *window = frontWindow();
    if (window) {
        NSView *content = window.contentView;
        NSBitmapImageRep *image = [content bitmapImageRepForCachingDisplayInRect:content.bounds];
        [content cacheDisplayInRect:content.bounds toBitmapImageRep:image];
        [[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[path stringByAppendingPathComponent:@"success.png"] atomically:YES];
    }
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

@interface SpreadsheetRowHeaderView : NSView
@property(nonatomic) CGFloat tableHeaderHeight;
@property(nonatomic) CGFloat rowHeight;
- (NSString *)textForRow:(NSInteger)row;
@end

@interface FormulaBarTextField : NSTextField
@property(nonatomic, assign) SpreadsheetWindowController *spreadsheetController;
@end

// Ribbon controls deliberately do not become first responder when clicked.
// Their actions still fire, but a click cannot cause AppKit to end a grid or
// formula-bar edit before the explicit action has been translated.
@interface RibbonSegmentedControl : NSSegmentedControl
@end
@implementation RibbonSegmentedControl
- (BOOL)acceptsFirstResponder { return NO; }
@end

@interface RibbonPopUpButton : NSPopUpButton
@end
@implementation RibbonPopUpButton
- (BOOL)acceptsFirstResponder { return NO; }
@end

@interface SpreadsheetWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
{
    std::unique_ptr<FormulaEditingSession> _formulaSession;
    SelectionModel _selection;
}
- (instancetype)initWithDocument:(WorkbookDocument *)document;
- (IBAction)copy:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)insertSum:(id)sender;
- (IBAction)insertAverage:(id)sender;
- (IBAction)undo:(id)sender;
- (IBAction)redo:(id)sender;
- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)column;
- (void)handleCellMouseDownAtRow:(NSInteger)row column:(NSInteger)column event:(NSEvent *)event;
- (void)handleCellDragEvent:(NSEvent *)event;
- (void)cancelFormulaBar;
- (void)insertFormulaReference:(FormulaEditingSession::Range)range;
- (BOOL)isFormulaEditing;
- (BOOL)isReferenceCellAtRow:(NSInteger)row column:(NSInteger)column;
- (BOOL)isSelectedCellAtRow:(NSInteger)row column:(NSInteger)column;
- (BOOL)isActiveCellAtRow:(NSInteger)row column:(NSInteger)column;
- (BOOL)runEndToEndCheck:(NSString **)failure;
- (void)configureCell:(SpreadsheetCellTextField *)cell row:(NSInteger)row column:(NSInteger)column includeValue:(BOOL)includeValue;
- (void)syncRowHeaderGeometry;
- (void)tableHeaderFrameDidChange:(NSNotification *)notification;
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

- (void)mouseDragged:(NSEvent *)event
{
    [self.spreadsheetController handleCellDragEvent:event];
    [super mouseDragged:event];
}
@end

@implementation SpreadsheetCellTextField

- (void)mouseDown:(NSEvent *)event
{
    [self.spreadsheetController handleCellMouseDownAtRow:_spreadsheetRow column:_spreadsheetColumn event:event];
    if (![self.spreadsheetController isReferenceCellAtRow:_spreadsheetRow column:_spreadsheetColumn]) [super mouseDown:event];
}

- (void)mouseDragged:(NSEvent *)event
{
    [self.spreadsheetController handleCellDragEvent:event];
    [super mouseDragged:event];
}

- (void)drawRect:(NSRect)dirtyRect
{
    const BOOL reference = [self.spreadsheetController isReferenceCellAtRow:_spreadsheetRow column:_spreadsheetColumn];
    const BOOL selected = [self.spreadsheetController isSelectedCellAtRow:_spreadsheetRow column:_spreadsheetColumn];
    if (reference) [[NSColor.systemOrangeColor colorWithAlphaComponent:0.20] setFill];
    else if (selected) [[NSColor.selectedControlColor colorWithAlphaComponent:0.18] setFill];
    if (reference || selected) NSRectFill(self.bounds);
    [super drawRect:dirtyRect];
    if (reference) {
        [NSColor.systemOrangeColor setStroke];
        NSFrameRectWithWidth(self.bounds, 2.0);
    } else if ([self.spreadsheetController isActiveCellAtRow:_spreadsheetRow column:_spreadsheetColumn]) {
        [NSColor.keyboardFocusIndicatorColor setStroke];
        NSFrameRectWithWidth(self.bounds, 2.0);
    }
}
@end

@implementation SpreadsheetRowHeaderView
- (BOOL)isFlipped { return YES; }

- (NSString *)textForRow:(NSInteger)row { return [NSString stringWithFormat:@"%ld", static_cast<long>(row + 1)]; }

- (void)drawRect:(NSRect)dirtyRect
{
    [NSColor.controlBackgroundColor setFill];
    NSRectFill(dirtyRect);
    const CGFloat headerHeight = _tableHeaderHeight;
    const CGFloat rowHeight = _rowHeight;
    const NSInteger firstRow = std::max<NSInteger>(0, static_cast<NSInteger>(std::floor((NSMinY(dirtyRect) - headerHeight) / rowHeight)));
    const NSInteger lastRow = std::min<NSInteger>(Workbook::RowCount - 1, static_cast<NSInteger>(std::ceil((NSMaxY(dirtyRect) - headerHeight) / rowHeight)));
    NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:12], NSForegroundColorAttributeName: NSColor.secondaryLabelColor};
    for (NSInteger row = firstRow; row <= lastRow; ++row) {
        const CGFloat y = headerHeight + row * rowHeight;
        const NSString *text = [self textForRow:row];
        const NSSize size = [text sizeWithAttributes:attributes];
        [text drawAtPoint:NSMakePoint(NSWidth(self.bounds) - size.width - 6.0, y + (rowHeight - size.height) / 2.0) withAttributes:attributes];
        [NSColor.separatorColor setFill];
        NSRectFill(NSMakeRect(0, y + rowHeight - 1.0, NSWidth(self.bounds), 1.0));
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
    [self updateChangeCount:_workbook->isModified() ? NSChangeDone : NSChangeCleared];
}
@end

@interface SpreadsheetWindowController ()
@property(nonatomic, assign) WorkbookDocument *workbookDocument;
@property(nonatomic, strong) NSTableView *table;
@property(nonatomic, strong) SpreadsheetRowHeaderView *rowHeaderView;
@property(nonatomic, strong) NSScrollView *worksheetScroll;
@property(nonatomic, strong) NSScrollView *rowHeaderScroll;
@property(nonatomic, strong) FormulaBarTextField *formulaBar;
@property(nonatomic, strong) NSTextField *statusField;
@property(nonatomic, strong) NSPopUpButton *fontFamilyControl;
@property(nonatomic, strong) NSPopUpButton *fontSizeControl;
@property(nonatomic, strong) NSSegmentedControl *styleControl;
@property(nonatomic, strong) NSSegmentedControl *alignmentControl;
@property(nonatomic, strong) NSPopUpButton *functionControl;
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
    _fontFamilyControl = [[RibbonPopUpButton alloc] init];
    [_fontFamilyControl addItemsWithTitles:@[@"Helvetica", @"Times-Roman", @"Courier"]];
    _fontFamilyControl.target = self; _fontFamilyControl.action = @selector(changeFontFamily:); _fontFamilyControl.translatesAutoresizingMaskIntoConstraints = NO;
    _fontSizeControl = [[RibbonPopUpButton alloc] init];
    [_fontSizeControl addItemsWithTitles:@[@"10", @"12", @"14", @"18", @"24"]];
    _fontSizeControl.target = self; _fontSizeControl.action = @selector(changeFontSize:); _fontSizeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _styleControl = [[RibbonSegmentedControl alloc] initWithFrame:NSZeroRect];
    _styleControl.segmentCount = 3; [_styleControl setLabel:@"B" forSegment:0]; [_styleControl setLabel:@"I" forSegment:1]; [_styleControl setLabel:@"U" forSegment:2];
    _styleControl.trackingMode = NSSegmentSwitchTrackingSelectAny; _styleControl.target = self; _styleControl.action = @selector(changeStyle:); _styleControl.segmentStyle = NSSegmentStyleSmallSquare; _styleControl.translatesAutoresizingMaskIntoConstraints = NO;
    _alignmentControl = [[RibbonSegmentedControl alloc] initWithFrame:NSZeroRect];
    _alignmentControl.segmentCount = 3; [_alignmentControl setLabel:@"Left" forSegment:0]; [_alignmentControl setLabel:@"Center" forSegment:1]; [_alignmentControl setLabel:@"Right" forSegment:2];
    _alignmentControl.trackingMode = NSSegmentSwitchTrackingSelectOne; _alignmentControl.target = self; _alignmentControl.action = @selector(changeAlignment:); _alignmentControl.segmentStyle = NSSegmentStyleSmallSquare; _alignmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    _functionControl = [[RibbonPopUpButton alloc] init];
    [_functionControl addItemsWithTitles:@[@"Functions", @"SUM", @"AVERAGE", @"MIN", @"MAX", @"COUNT"]];
    _functionControl.target = self; _functionControl.action = @selector(insertFunction:); _functionControl.translatesAutoresizingMaskIntoConstraints = NO;
    [ribbon addSubview:_fontFamilyControl]; [ribbon addSubview:_fontSizeControl]; [ribbon addSubview:_styleControl]; [ribbon addSubview:_alignmentControl]; [ribbon addSubview:_functionControl];
    [NSLayoutConstraint activateConstraints:@[
        [ribbon.heightAnchor constraintEqualToConstant:34], [_fontFamilyControl.leadingAnchor constraintEqualToAnchor:ribbon.leadingAnchor constant:10], [_fontFamilyControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_fontSizeControl.leadingAnchor constraintEqualToAnchor:_fontFamilyControl.trailingAnchor constant:6], [_fontSizeControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_styleControl.leadingAnchor constraintEqualToAnchor:_fontSizeControl.trailingAnchor constant:10], [_styleControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_alignmentControl.leadingAnchor constraintEqualToAnchor:_styleControl.trailingAnchor constant:10], [_alignmentControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor],
        [_functionControl.leadingAnchor constraintEqualToAnchor:_alignmentControl.trailingAnchor constant:10], [_functionControl.centerYAnchor constraintEqualToAnchor:ribbon.centerYAnchor]
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

    NSStackView *gridRow = [NSStackView stackViewWithViews:@[]];
    gridRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    gridRow.spacing = 0;
    NSScrollView *rowHeaderScroll = [[NSScrollView alloc] init];
    rowHeaderScroll.hasVerticalScroller = NO; rowHeaderScroll.hasHorizontalScroller = NO; rowHeaderScroll.borderType = NSBezelBorder;
    _rowHeaderView = [[SpreadsheetRowHeaderView alloc] initWithFrame:NSMakeRect(0, 0, 42, 0)];
    rowHeaderScroll.documentView = _rowHeaderView;
    [rowHeaderScroll.widthAnchor constraintEqualToConstant:42].active = YES;

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES; scroll.hasHorizontalScroller = YES; scroll.borderType = NSBezelBorder;
    _table = [[SpreadsheetTableView alloc] init];
    static_cast<SpreadsheetTableView *>(_table).spreadsheetController = self;
    _table.dataSource = self; _table.delegate = self; _table.allowsMultipleSelection = NO; _table.allowsEmptySelection = YES;
    _table.allowsColumnSelection = NO; _table.usesAlternatingRowBackgroundColors = YES; _table.rowHeight = 25; _table.intercellSpacing = NSMakeSize(1, 2);
    _table.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    for (NSInteger column = 0; column < Workbook::ColumnCount; ++column) {
        NSTableColumn *tableColumn = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%ld", static_cast<long>(column)]];
        tableColumn.title = columnName(column); tableColumn.width = 102; tableColumn.minWidth = 72; tableColumn.editable = YES;
        [_table addTableColumn:tableColumn];
    }
    scroll.documentView = _table;
    _worksheetScroll = scroll;
    _rowHeaderScroll = rowHeaderScroll;
    scroll.contentView.postsBoundsChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(worksheetScrollDidChange:) name:NSViewBoundsDidChangeNotification object:scroll.contentView];
    _table.headerView.postsFrameChangedNotifications = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableHeaderFrameDidChange:) name:NSViewFrameDidChangeNotification object:_table.headerView];
    [self syncRowHeaderGeometry];
    [gridRow addArrangedSubview:rowHeaderScroll];
    [gridRow addArrangedSubview:scroll];
    [stack addArrangedSubview:gridRow];

    NSView *statusRow = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 26)];
    _statusField = [NSTextField labelWithString:@"Ready"];
    _statusField.font = [NSFont systemFontOfSize:12]; _statusField.textColor = NSColor.secondaryLabelColor; _statusField.translatesAutoresizingMaskIntoConstraints = NO;
    [statusRow addSubview:_statusField];
    [NSLayoutConstraint activateConstraints:@[[statusRow.heightAnchor constraintEqualToConstant:26], [_statusField.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor constant:12], [_statusField.centerYAnchor constraintEqualToAnchor:statusRow.centerYAnchor]]];
    [stack addArrangedSubview:statusRow];
    _activeRow = 0;
    _activeColumn = 0;
    _selection = SelectionModel({0, 0});
    [self updateFormulaBar];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return Workbook::RowCount; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    SpreadsheetCellTextField *cell = [tableView makeViewWithIdentifier:@"SpreadsheetCell" owner:self];
    if (!cell) {
        cell = [[SpreadsheetCellTextField alloc] init]; cell.identifier = @"SpreadsheetCell"; cell.bordered = NO; cell.backgroundColor = NSColor.clearColor;
        cell.lineBreakMode = NSLineBreakByTruncatingTail; cell.editable = YES; cell.selectable = YES; cell.delegate = self;
    }
    [self configureCell:cell row:row column:column.identifier.integerValue includeValue:YES];
    return cell;
}

- (void)worksheetScrollDidChange:(NSNotification *)notification
{
    NSPoint origin = _rowHeaderScroll.contentView.bounds.origin;
    origin.y = _worksheetScroll.contentView.bounds.origin.y;
    [_rowHeaderScroll.contentView scrollToPoint:origin];
    [_rowHeaderScroll reflectScrolledClipView:_rowHeaderScroll.contentView];
}

- (void)tableHeaderFrameDidChange:(NSNotification *)notification
{
    [self syncRowHeaderGeometry];
}

- (void)syncRowHeaderGeometry
{
    const CGFloat headerHeight = _table.headerView.bounds.size.height;
    const CGFloat rowHeight = _table.rowHeight + _table.intercellSpacing.height;
    _rowHeaderView.tableHeaderHeight = headerHeight;
    _rowHeaderView.rowHeight = rowHeight;
    _rowHeaderView.frame = NSMakeRect(0, 0, 42, headerHeight + Workbook::RowCount * rowHeight);
    [_rowHeaderView setNeedsDisplay:YES];
}

- (void)configureCell:(SpreadsheetCellTextField *)cell row:(NSInteger)row column:(NSInteger)column includeValue:(BOOL)includeValue
{
    cell.spreadsheetController = self;
    cell.spreadsheetRow = row;
    cell.spreadsheetColumn = column;
    if (includeValue) cell.stringValue = asNSString([self.workbookDocument workbook]->displayValue(static_cast<int>(row), static_cast<int>(column)));
    const CellFormat format = [self.workbookDocument workbook]->cellFormat(static_cast<int>(row), static_cast<int>(column));
    NSFont *font = [NSFont fontWithName:asNSString(format.fontFamily) size:format.fontSize];
    if (!font) font = [NSFont systemFontOfSize:format.fontSize];
    NSFontTraitMask traits = 0;
    if (format.bold) traits |= NSBoldFontMask;
    if (format.italic) traits |= NSItalicFontMask;
    if (traits) font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:traits];
    cell.font = font;
    cell.alignment = format.alignment == HorizontalAlignment::Center ? NSTextAlignmentCenter : format.alignment == HorizontalAlignment::Right ? NSTextAlignmentRight : NSTextAlignmentLeft;
    if (format.underline) cell.attributedStringValue = [[NSAttributedString alloc] initWithString:cell.stringValue attributes:@{NSFontAttributeName: font, NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)}];
    else cell.attributedStringValue = [[NSAttributedString alloc] initWithString:cell.stringValue attributes:@{NSFontAttributeName: font}];
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
    // NSTableView tracks rows only. Its reload and responder notifications can
    // report a stale row, so logical cell selection is updated only by explicit
    // grid interaction above.
}
- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
    if ([notification.object isKindOfClass:SpreadsheetCellTextField.class]) {
        SpreadsheetCellTextField *cell = static_cast<SpreadsheetCellTextField *>(notification.object);
        const std::string raw = [self.workbookDocument workbook]->rawValue(static_cast<int>(cell.spreadsheetRow), static_cast<int>(cell.spreadsheetColumn));
        cell.stringValue = asNSString(raw);
        if ([cell.currentEditor isKindOfClass:NSTextView.class]) static_cast<NSTextView *>(cell.currentEditor).string = cell.stringValue;
        return;
    }
    if (notification.object == _formulaBar && !_formulaSession->isEditing()) {
        _formulaSession->begin({static_cast<int>(_activeRow), static_cast<int>(_activeColumn)}, [self.workbookDocument workbook]->rawValue(static_cast<int>(_activeRow), static_cast<int>(_activeColumn)));
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if (notification.object == _formulaBar && _formulaSession->isEditing()) _formulaSession->setDraft(asString(_formulaBar.stringValue));
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (control == _formulaBar && (commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertLineBreak:))) {
        if (_formulaSession->isEditing()) _formulaSession->setDraft(asString(textView.string));
        [self commitFormulaBar];
        [self.window makeFirstResponder:_table];
        return YES;
    }
    if (control == _formulaBar && commandSelector == @selector(cancelOperation:)) {
        [self cancelFormulaBar];
        return YES;
    }
    return NO;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if ([notification.object isKindOfClass:SpreadsheetCellTextField.class]) {
        SpreadsheetCellTextField *cell = static_cast<SpreadsheetCellTextField *>(notification.object);
        const NSInteger movement = [notification.userInfo[@"NSTextMovement"] integerValue];
        if (movement == NSCancelTextMovement) { [_table reloadData]; return; }
        [self tableView:_table setObjectValue:cell.stringValue forTableColumn:_table.tableColumns[cell.spreadsheetColumn] row:cell.spreadsheetRow];
        return;
    }
    if (notification.object != _formulaBar) return;
    if (_discardingFormulaEdit) { _discardingFormulaEdit = NO; return; }
    if (!_formulaSession->isEditing()) return;
    _formulaSession->setDraft(asString(_formulaBar.stringValue));
    const NSInteger movement = [notification.userInfo[@"NSTextMovement"] integerValue];
    if (movement == NSReturnTextMovement) [self commitFormulaBar];
    else if (movement == NSCancelTextMovement) [self cancelFormulaBar];
}

- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)column
{
    if (row < 0 || row >= Workbook::RowCount || column < 0 || column >= Workbook::ColumnCount) return;
    _activeRow = row;
    _activeColumn = column;
    _selection.select({static_cast<int>(row), static_cast<int>(column)});
    [_table setNeedsDisplay:YES];
    [self updateFormulaBar];
}

- (void)handleCellMouseDownAtRow:(NSInteger)row column:(NSInteger)column event:(NSEvent *)event
{
    if (!_formulaSession->isEditing()) {
        if (event.modifierFlags & NSEventModifierFlagShift) {
            _activeRow = row;
            _activeColumn = column;
            _selection.extendTo({static_cast<int>(row), static_cast<int>(column)});
            [_table setNeedsDisplay:YES];
            [self updateFormulaBar];
        } else {
            [self selectCellAtRow:row column:column];
        }
        return;
    }
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
    [self insertFormulaReference:range];
}

- (void)handleCellDragEvent:(NSEvent *)event
{
    if (_formulaSession->isEditing()) return;
    const NSPoint point = [_table convertPoint:event.locationInWindow fromView:nil];
    const NSInteger row = [_table rowAtPoint:point];
    const NSInteger column = [_table columnAtPoint:point];
    if (row < 0 || column < 0) return;
    _selection.extendTo({static_cast<int>(row), static_cast<int>(column)});
    _activeRow = row;
    _activeColumn = column;
    [_table setNeedsDisplay:YES];
    [self updateFormulaBar];
}

- (void)insertFormulaReference:(FormulaEditingSession::Range)range
{
    if (!_formulaSession->isEditing()) return;
    _formulaSession->insertReference(range, _formulaSession->draft().size());
    _formulaBar.stringValue = asNSString(_formulaSession->draft());
    [self.window makeFirstResponder:_formulaBar];
    NSTextView *editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    if (editor) editor.selectedRange = NSMakeRange(_formulaBar.stringValue.length, 0);
    [_table reloadData];
}

- (BOOL)isReferenceCellAtRow:(NSInteger)row column:(NSInteger)column
{
    if (!_formulaSession->isEditing()) return NO;
    const std::optional<FormulaEditingSession::Range> range = _formulaSession->referenceRange();
    if (!range) return NO;
    return row >= std::min(range->first.row, range->last.row) && row <= std::max(range->first.row, range->last.row)
        && column >= std::min(range->first.column, range->last.column) && column <= std::max(range->first.column, range->last.column);
}

- (BOOL)isFormulaEditing { return _formulaSession->isEditing(); }

- (BOOL)isSelectedCellAtRow:(NSInteger)row column:(NSInteger)column
{
    return !_formulaSession->isEditing() && _selection.contains({static_cast<int>(row), static_cast<int>(column)});
}

- (BOOL)isActiveCellAtRow:(NSInteger)row column:(NSInteger)column
{
    return !_formulaSession->isEditing() && _selection.isActive({static_cast<int>(row), static_cast<int>(column)});
}

- (void)updateFormulaBar
{
    if (_updatingFormulaBar || _formulaSession->isEditing() || _activeRow < 0 || _activeColumn < 0) return;
    _updatingFormulaBar = YES;
    _formulaBar.stringValue = asNSString([self.workbookDocument workbook]->rawValue(static_cast<int>(_activeRow), static_cast<int>(_activeColumn)));
    _statusField.stringValue = @"";
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
    _discardingFormulaEdit = _formulaBar.currentEditor != nil;
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
    // Capture the logical selection before an AppKit control can affect visual
    // focus. Formatting never commits or cancels a cell/formula edit.
    const SelectionModel::Range selection = _selection.range();
    const NSInteger firstRow = selection.first.row;
    const NSInteger firstColumn = selection.first.column;
    const NSInteger lastRow = selection.last.row;
    const NSInteger lastColumn = selection.last.column;
    if ([self.workbookDocument workbook]->setFormatRange(static_cast<int>(firstRow), static_cast<int>(firstColumn), static_cast<int>(lastRow), static_cast<int>(lastColumn), format)) {
        [self.workbookDocument workbookDidChange];
        for (NSInteger row = firstRow; row <= lastRow; ++row) for (NSInteger column = firstColumn; column <= lastColumn; ++column) {
            SpreadsheetCellTextField *cell = static_cast<SpreadsheetCellTextField *>([_table viewAtColumn:column row:row makeIfNecessary:NO]);
            if (cell) [self configureCell:cell row:row column:column includeValue:NO];
        }
        [_table setNeedsDisplay:YES];
        [self updateRibbonControls];
    }
}

- (IBAction)changeFontFamily:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.fontFamily = asString(_fontFamilyControl.titleOfSelectedItem); [self applyFormat:format]; }
- (IBAction)changeFontSize:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.fontSize = _fontSizeControl.titleOfSelectedItem.doubleValue; [self applyFormat:format]; }
- (IBAction)changeStyle:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.bold = [_styleControl isSelectedForSegment:0]; format.italic = [_styleControl isSelectedForSegment:1]; format.underline = [_styleControl isSelectedForSegment:2]; [self applyFormat:format]; }
- (IBAction)changeAlignment:(id)sender { CellFormat format = [self.workbookDocument workbook]->cellFormat(_activeRow, _activeColumn); format.alignment = _alignmentControl.selectedSegment == 1 ? HorizontalAlignment::Center : _alignmentControl.selectedSegment == 2 ? HorizontalAlignment::Right : HorizontalAlignment::Left; [self applyFormat:format]; }

- (void)selectedRangeFirstRow:(NSInteger *)firstRow firstColumn:(NSInteger *)firstColumn lastRow:(NSInteger *)lastRow lastColumn:(NSInteger *)lastColumn
{
    const SelectionModel::Range selection = _selection.range();
    *firstRow = selection.first.row;
    *lastRow = selection.last.row;
    *firstColumn = selection.first.column;
    *lastColumn = selection.last.column;
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
    if (!_formulaSession->isEditing()) [self beginFunction:function];
    else if (_formulaSession->insertFunction(asString(function), _formulaSession->draft().size())) {
        _formulaBar.stringValue = asNSString(_formulaSession->draft());
        [self.window makeFirstResponder:_formulaBar];
        NSTextView *editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
        if (editor) {
            editor.string = _formulaBar.stringValue;
            editor.selectedRange = NSMakeRange(_formulaBar.stringValue.length, 0);
        }
    }
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

- (IBAction)undo:(id)sender
{
    if ([self.workbookDocument workbook]->undo()) {
        [self.workbookDocument workbookDidChange];
        [_table reloadData];
        [self updateFormulaBar];
    }
}

- (IBAction)redo:(id)sender
{
    if ([self.workbookDocument workbook]->redo()) {
        [self.workbookDocument workbookDidChange];
        [_table reloadData];
        [self updateFormulaBar];
    }
}

- (BOOL)runEndToEndCheck:(NSString **)failure
{
    const auto require = [failure](BOOL condition, NSString *message) {
        if (!condition && failure) *failure = message;
        return condition;
    };
    Workbook *workbook = self.workbookDocument.workbook;
    NSTableColumn *firstColumn = _table.tableColumns[0];
    NSTableColumn *secondColumn = _table.tableColumns[1];
    NSTableColumn *thirdColumn = _table.tableColumns[2];

    [self.window setContentSize:NSMakeSize(1060, 420)];
    [self.window.contentView layoutSubtreeIfNeeded];
    [self tableView:_table setObjectValue:@"2" forTableColumn:firstColumn row:0];
    [self tableView:_table setObjectValue:@"3" forTableColumn:secondColumn row:0];
    [self tableView:_table setObjectValue:@"=SUM(A1,B1)" forTableColumn:thirdColumn row:0];
    if (!require(workbook->displayValue(0, 2) == "5", @"Initial formula entry did not evaluate in C1.")) return NO;
    if (!require([_formulaBar.stringValue isEqualToString:@"=SUM(A1,B1)"], @"Formula bar did not retain C1's raw formula source.")) return NO;
    if (!require(_table.selectedRow == -1, @"Logical cell selection allowed NSTableView row selection rendering.")) return NO;
    if (!require([self isActiveCellAtRow:0 column:2] && [self isSelectedCellAtRow:0 column:2]
            && ![self isSelectedCellAtRow:1 column:2], @"Clicking C1 did not create a single logical cell selection.")) return NO;

    [_table layoutSubtreeIfNeeded];
    const NSRect firstCell = [_table frameOfCellAtColumn:0 row:0];
    const NSRect lastCell = [_table frameOfCellAtColumn:2 row:1];
    const NSPoint clickPoint = [_table convertPoint:NSMakePoint(NSMidX(firstCell), NSMidY(firstCell)) toView:nil];
    const NSPoint dragPoint = [_table convertPoint:NSMakePoint(NSMidX(lastCell), NSMidY(lastCell)) toView:nil];
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:clickPoint modifierFlags:0 timestamp:0
        windowNumber:self.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1.0];
    NSEvent *drag = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDragged location:dragPoint modifierFlags:0 timestamp:0
        windowNumber:self.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1.0];
    [self handleCellMouseDownAtRow:0 column:0 event:click];
    [self handleCellDragEvent:drag];
    if (!require([self isSelectedCellAtRow:1 column:2] && ![self isSelectedCellAtRow:2 column:2], @"Dragging a logical range did not select only its rectangle.")) return NO;
    if (!require(std::abs(_rowHeaderView.bounds.size.height - (_table.headerView.bounds.size.height + Workbook::RowCount * (_table.rowHeight + _table.intercellSpacing.height))) < 0.1,
            @"Row header geometry did not match the table header and row heights.")) return NO;
    if (!require([[_rowHeaderView textForRow:0] isEqualToString:@"1"], @"The first row header was not one-based.")) return NO;
    [_worksheetScroll.contentView scrollToPoint:NSMakePoint(0, 25)];
    [self worksheetScrollDidChange:nil];
    if (!require(std::abs(_worksheetScroll.contentView.bounds.origin.y - _rowHeaderScroll.contentView.bounds.origin.y) < 0.1,
            @"Row headers did not stay vertically synchronized with worksheet scrolling.")) return NO;

    // Regression: a ribbon action on an edited non-top cell must be a pure
    // formatting operation. The control intentionally declines first-responder
    // status, so the editor and logical selection remain in place.
    [self tableView:_table setObjectValue:@"keep text" forTableColumn:thirdColumn row:4];
    [self selectCellAtRow:4 column:2];
    [_table reloadData]; [_table layoutSubtreeIfNeeded];
    SpreadsheetCellTextField *editedCell = static_cast<SpreadsheetCellTextField *>([_table viewAtColumn:2 row:4 makeIfNecessary:YES]);
    [editedCell selectText:nil];
    if (!require(editedCell.currentEditor != nil, @"Could not begin the non-top cell editing regression scenario.")) return NO;
    [self.window makeFirstResponder:_styleControl];
    [_styleControl setSelected:YES forSegment:0]; [self changeStyle:_styleControl];
    if (!require(workbook->rawValue(4, 2) == "keep text" && _activeRow == 4 && _activeColumn == 2 && workbook->cellFormat(4, 2).bold,
            @"Bold changed a non-top edited cell instead of only formatting it.")) return NO;
    [_alignmentControl setSelected:YES forSegment:1]; [self changeAlignment:_alignmentControl];
    if (!require(workbook->rawValue(4, 2) == "keep text" && _activeRow == 4 && _activeColumn == 2
            && workbook->cellFormat(4, 2).alignment == HorizontalAlignment::Center,
            @"Center Alignment changed a non-top edited cell instead of only formatting it.")) return NO;
    [self.window makeFirstResponder:_table];

    [self tableView:_table setObjectValue:@"=SUM(A1,B1)" forTableColumn:thirdColumn row:5];
    [self selectCellAtRow:5 column:2];
    _selection.extendTo({5, 3});
    [_styleControl setSelected:YES forSegment:0]; [self changeStyle:_styleControl];
    [_alignmentControl setSelected:YES forSegment:1]; [self changeAlignment:_alignmentControl];
    if (!require(workbook->rawValue(5, 2) == "=SUM(A1,B1)" && workbook->rawValue(5, 3).empty()
            && workbook->cellFormat(5, 2).bold && workbook->cellFormat(5, 3).alignment == HorizontalAlignment::Center,
            @"Ribbon formatting changed a formula cell or range contents.")) return NO;

    [self selectCellAtRow:0 column:2];
    [_table reloadData];
    [_table layoutSubtreeIfNeeded];
    SpreadsheetCellTextField *formulaCell = static_cast<SpreadsheetCellTextField *>([_table viewAtColumn:2 row:0 makeIfNecessary:YES]);
    [formulaCell selectText:nil];
    if (!require([formulaCell.stringValue isEqualToString:@"=SUM(A1,B1)"], @"Editing a formula cell did not replace its rendered value with raw contents.")) return NO;
    [self.window makeFirstResponder:_fontFamilyControl];
    if (!require(workbook->rawValue(0, 2) == "=SUM(A1,B1)", @"A first-responder change rewrote a formula with its rendered value.")) return NO;

    [self selectCellAtRow:0 column:0];
    _selection.extendTo({1, 2});
    [_fontFamilyControl selectItemWithTitle:@"Courier"];
    [self changeFontFamily:_fontFamilyControl];
    [_fontSizeControl selectItemWithTitle:@"18"];
    [self changeFontSize:_fontSizeControl];
    [_styleControl setSelected:YES forSegment:0]; [_styleControl setSelected:YES forSegment:1]; [_styleControl setSelected:YES forSegment:2];
    [self changeStyle:_styleControl];
    [_alignmentControl setSelected:YES forSegment:2];
    [self changeAlignment:_alignmentControl];
    const CellFormat expectedFormat = workbook->cellFormat(1, 2);
    if (!require(expectedFormat.fontFamily == "Courier" && expectedFormat.fontSize == 18.0 && expectedFormat.bold && expectedFormat.italic && expectedFormat.underline && expectedFormat.alignment == HorizontalAlignment::Right, @"Ribbon formatting did not apply to the selected rectangle.")) return NO;
    if (!require(workbook->rawValue(0, 0) == "2" && workbook->rawValue(0, 2) == "=SUM(A1,B1)" && workbook->rawValue(1, 2).empty(), @"Ribbon formatting changed raw cell contents.")) return NO;
    [_table reloadData];
    [_table layoutSubtreeIfNeeded];
    NSTextField *formattedCell = static_cast<NSTextField *>([_table viewAtColumn:2 row:0 makeIfNecessary:YES]);
    if (!require(formattedCell.alignment == NSTextAlignmentRight && formattedCell.font.pointSize == 18.0, @"Formatted cell did not render the selected alignment and size.")) return NO;

    // Formula-bar focus has the same ribbon contract: an unchanged draft and
    // an uncommitted draft both survive formatting, and Escape alone cancels.
    [self selectCellAtRow:3 column:3];
    [self tableView:_table setObjectValue:@"formula keep" forTableColumn:_table.tableColumns[3] row:3];
    [_formulaBar selectText:nil];
    if (!_formulaSession->isEditing()) [self controlTextDidBeginEditing:[NSNotification notificationWithName:NSControlTextDidBeginEditingNotification object:_formulaBar]];
    [_styleControl setSelected:YES forSegment:0]; [self changeStyle:_styleControl];
    if (!require(_formulaSession->isEditing() && _formulaSession->draft() == "formula keep" && workbook->rawValue(3, 3) == "formula keep",
            @"Formatting committed an unchanged focused formula field.")) return NO;
    NSTextView *formulaEditor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    formulaEditor.string = @"discard formula draft";
    _formulaBar.stringValue = formulaEditor.string;
    [self controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:_formulaBar]];
    [_alignmentControl setSelected:YES forSegment:1]; [self changeAlignment:_alignmentControl];
    if (!require(_formulaSession->draft() == "discard formula draft" && workbook->rawValue(3, 3) == "formula keep",
            @"Formatting committed or replaced a formula-field draft.")) return NO;
    [self cancelFormulaBar];
    if (!require(workbook->rawValue(3, 3) == "formula keep" && !_formulaSession->isEditing(),
            @"Escape did not cancel the formatted formula-field draft.")) return NO;

    [self selectCellAtRow:0 column:3];
    [_formulaBar selectText:nil];
    if (!_formulaSession->isEditing()) [self controlTextDidBeginEditing:[NSNotification notificationWithName:NSControlTextDidBeginEditingNotification object:_formulaBar]];
    NSTextView *editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    if (!require(editor != nil && _formulaSession->isEditing(), @"Formula bar did not begin an editing session when it became first responder.")) return NO;
    editor.string = @"=C1*B1";
    _formulaBar.stringValue = editor.string;
    [self control:_formulaBar textView:editor doCommandBySelector:@selector(insertNewline:)];
    if (!require(workbook->rawValue(0, 3) == "=C1*B1" && workbook->displayValue(0, 3) == "15", @"Return did not commit and recalculate the formula bar draft.")) return NO;
    if (!require(_statusField.stringValue.length == 0 && !_formulaSession->isEditing(), @"Formula commit did not clear editing status.")) return NO;

    [self selectCellAtRow:0 column:4];
    workbook->setRawValue(0, 4, "keep");
    [_formulaBar selectText:nil];
    if (!_formulaSession->isEditing()) [self controlTextDidBeginEditing:[NSNotification notificationWithName:NSControlTextDidBeginEditingNotification object:_formulaBar]];
    editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    if (!require(editor != nil && _formulaSession->isEditing(), @"Formula bar did not start the Escape test session.")) return NO;
    editor.string = @"discard";
    _formulaBar.stringValue = editor.string;
    NSEvent *escape = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:self.window.windowNumber context:nil characters:@"\x1b" charactersIgnoringModifiers:@"\x1b" isARepeat:NO keyCode:53];
    [_formulaBar keyDown:escape];
    if (!require(workbook->rawValue(0, 4) == "keep" && _formulaBar.stringValue.length == 4 && _statusField.stringValue.length == 0, @"Escape did not restore the original formula-bar content.")) return NO;

    [self selectCellAtRow:0 column:5];
    [_functionControl selectItemWithTitle:@"SUM"];
    [_functionControl sendAction:_functionControl.action to:_functionControl.target];
    if (!require(_formulaSession->isEditing() && _formulaSession->draft() == "=SUM(" && workbook->rawValue(0, 5).empty(), @"Function dropdown committed instead of inserting a supported template.")) return NO;
    [self insertFormulaReference:{{0, 0}, {0, 1}}];
    if (!require(_formulaSession->draft() == "=SUM(A1:B1" && workbook->rawValue(0, 5).empty(), @"Range reference insertion changed the destination cell.")) return NO;
    _formulaSession->setDraft("=SUM (A1:B1)");
    _formulaBar.stringValue = asNSString(_formulaSession->draft());
    editor = static_cast<NSTextView *>(_formulaBar.currentEditor);
    if (!editor) editor = [[NSTextView alloc] init];
    editor.string = _formulaBar.stringValue;
    [self control:_formulaBar textView:editor doCommandBySelector:@selector(insertNewline:)];
    if (!require(workbook->displayValue(0, 5) == "5", @"Whitespace before a function parenthesis did not evaluate through the formula bar.")) return NO;

    [self tableView:_table setObjectValue:@"5" forTableColumn:firstColumn row:0];
    if (!require(workbook->displayValue(0, 2) == "8" && workbook->displayValue(0, 3) == "24" && workbook->displayValue(0, 5) == "8", @"Editing a precedent did not recalculate dependent formulas.")) return NO;
    [self undo:nil];
    if (!require(workbook->rawValue(0, 0) == "2" && workbook->displayValue(0, 3) == "15", @"Undo did not restore a cell edit and its dependent values.")) return NO;
    [self redo:nil];
    if (!require(workbook->rawValue(0, 0) == "5" && workbook->displayValue(0, 3) == "24", @"Redo did not restore a cell edit and its dependent values.")) return NO;
    [self undo:nil];
    [self undo:nil];
    if (!require(workbook->cellFormat(0, 0).alignment == HorizontalAlignment::Right, @"Undo removed formatting before undoing the latest cell edit.")) return NO;
    [self redo:nil];
    [self redo:nil];
    if (!require(workbook->cellFormat(0, 0).alignment == HorizontalAlignment::Right && workbook->rawValue(0, 0) == "5", @"Redo did not preserve formatting and cell edits together.")) return NO;

    [self.workbookDocument updateChangeCount:NSChangeCleared];
    workbook->markSaved();
    [self tableView:_table setObjectValue:@"2" forTableColumn:firstColumn row:0];
    if (!require(self.workbookDocument.isDocumentEdited, @"A workbook edit did not mark the document dirty.")) return NO;
    [self undo:nil];
    if (!require(!self.workbookDocument.isDocumentEdited, @"Undo to the saved workbook state left the document dirty.")) return NO;
    [self redo:nil];
    if (!require(self.workbookDocument.isDocumentEdited, @"Redo from the saved workbook state did not mark the document dirty.")) return NO;

    [self selectCellAtRow:0 column:2];
    if (!require([_formulaBar.stringValue isEqualToString:@"=SUM(A1,B1)"], @"Formula bar did not return the active cell raw contents after selection.")) return NO;
    return YES;
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
    SpreadsheetWindowController *controller = window ? static_cast<SpreadsheetWindowController *>(window.windowController) : nil;
    NSTableView *table = controller.table;
    if (window.visible && !table.hidden) {
        [window makeKeyAndOrderFront:nil];
        [controller selectCellAtRow:0 column:0];
        if (table.selectedRow != -1 || table.tableColumns.count == 0 || ![controller isActiveCellAtRow:0 column:0]) {
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
        if (!uiSmokeTestFailed && uiEndToEndTestMode) {
            SpreadsheetWindowController *controller = static_cast<SpreadsheetWindowController *>(window.windowController);
            NSString *failure = nil;
            if (![controller runEndToEndCheck:&failure]) {
                uiSmokeTestFailed = true;
                writeUiSmokeDiagnostics([@"FAIL:\n" stringByAppendingString:failure ? failure : @"The AppKit end-to-end scenario failed."]);
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
    [edit addItem:menuItem(@"Undo", @selector(undo:), @"z")]; [edit addItem:menuItem(@"Redo", @selector(redo:), @"Z")]; [edit addItem:NSMenuItem.separatorItem]; [edit addItem:menuItem(@"Cut", @selector(cut:), @"x")]; [edit addItem:menuItem(@"Copy", @selector(copy:), @"c")]; [edit addItem:menuItem(@"Paste", @selector(paste:), @"v")]; editItem.submenu = edit; [main addItem:editItem];
    NSMenuItem *formulaItem = menuItem(@"Formula", nil, nil); NSMenu *formula = [[NSMenu alloc] initWithTitle:@"Formula"];
    [formula addItem:menuItem(@"SUM", @selector(insertSum:), @"")]; [formula addItem:menuItem(@"AVERAGE", @selector(insertAverage:), @"")]; formulaItem.submenu = formula; [main addItem:formulaItem];
    NSApp.mainMenu = main;
}

int runRetroSpreadsheetApplication(int argc, const char *argv[])
{
    for (int index = 1; index < argc; ++index) {
        const std::string argument(argv[index]);
        if (argument == "--ui-smoke-test") uiSmokeTestMode = true;
        if (argument == "--ui-e2e-test") { uiSmokeTestMode = true; uiEndToEndTestMode = true; }
    }
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

#import <AppKit/AppKit.h>

// Presentation-only palette for the native AppKit surface. Keep these colors
// out of the portable workbook model and its persistence formats.
@interface SpreadsheetTheme : NSObject
+ (NSColor *)worksheetBackground;
+ (NSColor *)transparentBackground;
+ (NSColor *)toolbarBackground;
+ (NSColor *)formulaBarBackground;
+ (NSColor *)headerBackground;
+ (NSColor *)gridLine;
+ (NSColor *)primaryText;
+ (NSColor *)secondaryText;
+ (NSColor *)activeCellBorder;
+ (NSColor *)selectionFill;
+ (NSColor *)formulaReferenceBorder;
+ (NSColor *)formulaReferenceFill;
+ (NSColor *)separator;
+ (NSColor *)ribbonSelectionFill;
@end

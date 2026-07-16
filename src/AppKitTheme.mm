#import "AppKitTheme.h"

@implementation SpreadsheetTheme

+ (NSColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    return [NSColor colorWithSRGBRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1.0];
}

+ (NSColor *)worksheetBackground { return [self colorWithRed:248 green:242 blue:228]; }
+ (NSColor *)transparentBackground { return NSColor.clearColor; }
+ (NSColor *)toolbarBackground { return [self colorWithRed:229 green:223 blue:211]; }
+ (NSColor *)formulaBarBackground { return [self colorWithRed:252 green:248 blue:237]; }
+ (NSColor *)headerBackground { return [self colorWithRed:216 green:208 blue:194]; }
+ (NSColor *)gridLine { return [self colorWithRed:200 green:192 blue:178]; }
+ (NSColor *)primaryText { return [self colorWithRed:41 green:38 blue:32]; }
+ (NSColor *)secondaryText { return [self colorWithRed:105 green:97 blue:86]; }
+ (NSColor *)activeCellBorder { return [self colorWithRed:77 green:115 blue:154]; }
+ (NSColor *)selectionFill { return [self colorWithRed:217 green:229 blue:237]; }
+ (NSColor *)formulaReferenceBorder { return [self colorWithRed:183 green:106 blue:56]; }
+ (NSColor *)formulaReferenceFill { return [self colorWithRed:243 green:221 blue:205]; }
+ (NSColor *)separator { return [self colorWithRed:171 green:162 blue:147]; }
+ (NSColor *)ribbonSelectionFill { return [self colorWithRed:213 green:223 blue:229]; }

@end

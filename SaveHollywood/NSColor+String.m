#import "NSColor+String.h"

@implementation NSColor (String)

+ (NSColor *)colorFromString:(NSString *)inString
{
    NSColor * tColor=nil;
    
    if (inString!=nil)
    {
        NSArray * tComponents=[inString componentsSeparatedByString:@"|"];
    
        if ([tComponents count]==3)
        {
            tColor=[NSColor colorWithCalibratedRed:[[tComponents objectAtIndex:0] floatValue]
                                             green:[[tComponents objectAtIndex:1] floatValue]
                                              blue:[[tComponents objectAtIndex:2] floatValue]
                                             alpha:1.0];
        }
    }
    
    return tColor;
}

#pragma mark -

- (NSString *)stringValue
{
    NSColor *tColor = [self colorUsingColorSpaceName:@"NSCalibratedRGBColorSpace"];
    
    return([NSString stringWithFormat:@"%f|%f|%f",(float)[tColor redComponent],(float)[tColor greenComponent],(float)[tColor blueComponent]]);
}

@end

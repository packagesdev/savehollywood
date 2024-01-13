/*
 Copyright (c) 2012-2024, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SHTokenView.h"

@interface SHTokenView ()
{
    NSDictionary *_attributesDictionary;
    NSAttributedString * _cachedStringValue;
}
@end

CGFloat heightForStringDrawing(NSAttributedString *myString, CGFloat myWidth)
{
    NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithAttributedString:myString] autorelease];
    NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(myWidth, FLT_MAX)] autorelease];
    NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];

    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [textContainer setLineFragmentPadding:0.0];
    
    (void) [layoutManager glyphRangeForTextContainer:textContainer];
    return [layoutManager usedRectForTextContainer:textContainer].size.height;
}

@implementation SHTokenView

- (id)initWithFrame:(NSRect)frameRect
{
    self=[super initWithFrame:frameRect];
    
    if (self!=nil)
    {
        NSMutableParagraphStyle * tMutableParagraphStyle=[[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        tMutableParagraphStyle.alignment=NSCenterTextAlignment;
        
		NSShadow * tShadow=[NSShadow new];
		tShadow.shadowOffset=NSMakeSize(0,-1);
		tShadow.shadowColor=[NSColor colorWithDeviceWhite:0.65 alpha:1.0];
        
		_attributesDictionary=[@{NSForegroundColorAttributeName:[NSColor whiteColor],
								NSFontAttributeName:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]],
								NSParagraphStyleAttributeName:tMutableParagraphStyle,
								 NSShadowAttributeName:tShadow} copy];
								
		
        [tMutableParagraphStyle release];
        [tShadow release];
    }
    
    return self;
}

- (void)dealloc
{
    [_attributesDictionary release];
    
    [super dealloc];
}

- (void)setStringValue:(NSString *)inValue
{
    [_cachedStringValue release];
    
    _cachedStringValue=[[NSAttributedString alloc] initWithString:inValue
                                                       attributes:_attributesDictionary];
}

- (void)setUnsignedIntegerValue:(NSUInteger)inValue
{
    [self setStringValue:[NSString stringWithFormat:@"%lu",inValue]];
}

#pragma mark -

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect tBounds=[self bounds];
    
    // Draw background
    
    CGFloat tRadius=NSHeight(tBounds)*0.5;
    NSBezierPath * tBezierPath=[NSBezierPath bezierPathWithRoundedRect:tBounds xRadius:tRadius yRadius:tRadius];
    
    [[NSColor colorWithDeviceWhite:0.88 alpha:1.0] setFill];
    
    [tBezierPath fill];
    
    // Draw value
    
    if (_cachedStringValue!=nil)
    {
        CGFloat tHeight=[NSFont systemFontSizeForControlSize:NSRegularControlSize];//heightForStringDrawing(_cachedStringValue,tBounds.size.width);
        
        tBounds.origin.y=round(NSMidY(tBounds)-tHeight*0.5+1);
        tBounds.size.height=tHeight;
        
        [_cachedStringValue drawWithRect:tBounds options:0];
    }
}
@end

//
//  Copyright (C) 2012 Tobias Lensing, Marcus Tillmanns
//  http://icedcoffee-framework.org
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import <CoreText/CoreText.h>
#import "ICFont.h"
#import "ICFontCache.h"
#import "icFontTypes.h"

@interface ICFont ()

- (id)initWithName:(NSString *)fontName size:(CGFloat)size;
- (id)initWithCoreTextFont:(CTFontRef)ctFont;
- (void)setName:(NSString *)name;
- (void)setSize:(CGFloat)size;

- (CTFontRef)fontRef;
- (void)setFontRef:(CTFontRef)fontRef;

@end

@implementation ICFont

@synthesize name = _name;
@synthesize size = _size;

+ (id)fontWithName:(NSString *)fontName size:(CGFloat)size
{
    ICFont *cachedFont = [[ICFontCache sharedFontCache] fontForName:fontName];
    if (!cachedFont) {
        cachedFont = [[[[self class] alloc] initWithName:fontName
                                                    size:ICFontPointsToPixels(size)] autorelease];
    }
    return cachedFont;
}

+ (id)fontWithCoreTextFont:(CTFontRef)ctFont
{
    ICFont *cachedFont = [[ICFontCache sharedFontCache] fontForCTFontRef:ctFont];
    if (!cachedFont) {
        cachedFont = [[[[self class] alloc] initWithCoreTextFont:ctFont] autorelease];
    }
    return cachedFont;
}

- (void)setName:(NSString *)name
{
    [_name release];
    _name = [name copy];
}

- (void)setSize:(CGFloat)size
{
    _size = size;
}


// Private

- (id)initWithName:(NSString *)fontName size:(CGFloat)size
{
    CTFontRef ctFont = CTFontCreateWithName((CFStringRef)fontName, size, nil);
    self = [self initWithCoreTextFont:ctFont];
    CFRelease(ctFont);
    return self;
}

- (id)initWithCoreTextFont:(CTFontRef)ctFont
{
    if ((self = [super init])) {
        self.fontRef = ctFont;
        
        NSString *fontName = (NSString *)CTFontCopyDisplayName(self.fontRef);
        self.name = fontName;
        [fontName release];
        
        self.size = CTFontGetSize(self.fontRef);
        
        // Register font upon initialization
        [[ICFontCache sharedFontCache] registerFont:self];
    }
    return self;
}

- (void)dealloc
{
    self.fontRef = nil;
    self.name = nil;
    
    [super dealloc];
}

- (CTFontRef)fontRef
{
    return _fontRef;
}

- (void)setFontRef:(CTFontRef)fontRef
{
    if (_fontRef)
        CFRelease(_fontRef);
    _fontRef = fontRef;
    if (_fontRef)
        CFRetain(_fontRef);
}

@end

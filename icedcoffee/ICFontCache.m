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

#import "ICFontCache.h"

ICFontCache *g_sharedFontCache = nil;

@implementation ICFontCache

+ (id)sharedFontCache
{
    @synchronized (self) {
        if (!g_sharedFontCache) {
            g_sharedFontCache = [[[self class] alloc] init];
        }
    }
    return g_sharedFontCache;
}

- (id)init
{
    if ((self = [super init])) {
        _fontsByName = [[NSMutableDictionary alloc] init];
        _fontsByCTFontRef = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_fontsByName release];
    [_fontsByCTFontRef release];
    [super dealloc];
}

- (void)registerFont:(ICFont *)font
{
    if (![_fontsByName objectForKey:font.name]) {
        [_fontsByName setObject:font forKey:font.name];
        [_fontsByCTFontRef setObject:font forKey:[NSValue valueWithPointer:font.fontRef]];
    } else {
        NSLog(@"Warning: font cache already contains a font for name '%@'", font.name);
    }
}

- (ICFont *)fontForCTFontRef:(CTFontRef)fontRef
{
    return [_fontsByCTFontRef objectForKey:[NSValue valueWithPointer:fontRef]];
}

- (ICFont *)fontForName:(NSString *)name
{
    return [_fontsByName objectForKey:name];
}

@end
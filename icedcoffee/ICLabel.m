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

#import "ICLabel.h"
#import "ICSprite.h"
#import "ICTexture2D.h"
#import "ICShaderCache.h"
#import "ICShaderProgram.h"
#import "ICFont.h"
#import "ICTextLine.h"
#import "ICTextFrame.h"
#import "icUtils.h"

// FIXME: ICLabel support for 32-bit textures (?)

@interface ICLabel ()
+ (NSAttributedString *)attributedTextWithText:(NSString *)text font:(ICFont *)font;
+ (void)measureTextForAutoresizing:(NSString *)text font:(ICFont *)font origin:(kmVec3 *)origin size:(kmVec3 *)size;
- (void)autoresizeToText;
- (void)updateFrame;
@property (nonatomic, retain) ICTextFrame *textFrame;
@end

@implementation ICLabel

@synthesize textFrame = _textFrame;

@synthesize text = _text;
@synthesize attributedText = _attributedText;
@synthesize fontName = _fontName;
@synthesize fontSize = _fontSize;
@synthesize color = _color;
@synthesize autoresizesToTextSize = _autoresizesToTextSize;

+ (id)labelWithText:(NSString *)text fontName:(NSString *)fontName fontSize:(CGFloat)fontSize
{
    return [[[[self class] alloc] initWithText:text fontName:fontName fontSize:fontSize] autorelease];
}

- (id)initWithText:(NSString *)text fontName:(NSString *)fontName fontSize:(CGFloat)fontSize
{
    // Retreive font for font name and size
    ICFont *font = [ICFont fontWithName:fontName size:fontSize];
    
    kmVec3 origin, size;
    [[self class] measureTextForAutoresizing:text font:font origin:&origin size:&size];

    // Initialize with designated initializer
    if ((self = [self initWithSize:CGSizeMake(size.width, size.height)])) {
        self.autoresizesToTextSize = YES;
        
        self.origin = origin;
        
        self.fontName = fontName;
        self.fontSize = fontSize;
        self.text = text;
    }

    return self;
}

- (id)initWithSize:(CGSize)size
{
    if ((self = [super initWithSize:size])) {
        [self addObserver:self forKeyPath:@"attributedText" options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self forKeyPath:@"text" options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self forKeyPath:@"fontName" options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self forKeyPath:@"fontSize" options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self forKeyPath:@"color" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (id)initWithSize:(CGSize)size attributedText:(NSAttributedString *)attributedText
{
    if ((self = [self initWithSize:size])) {
        self.attributedText = attributedText;
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"attributedText"];
    [self removeObserver:self forKeyPath:@"text"];
    [self removeObserver:self forKeyPath:@"fontName"];
    [self removeObserver:self forKeyPath:@"fontSize"];
    [self removeObserver:self forKeyPath:@"color"];
    
    self.textFrame = nil;
    self.attributedText = nil;
    self.fontName = nil;
    
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (object == self) {
        if ([keyPath isEqualToString:@"text"] ||
            [keyPath isEqualToString:@"fontName"] ||
            [keyPath isEqualToString:@"fontSize"]) {
            if (self.fontName && self.fontSize && self.text) {
                ICFont *font = [ICFont fontWithName:self.fontName size:self.fontSize];
                self.attributedText = [[self class] attributedTextWithText:self.text font:font];
            }
        }
        if ([keyPath isEqualToString:@"attributedText"]) {
            [self updateFrame];
        }
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [_attributedText release];
    _attributedText = [attributedText copy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ICLabelTextDidChange object:self];
    
    [self setNeedsDisplay];
}

- (void)setFontName:(NSString *)fontName
{
    [_fontName release];
    _fontName = [fontName copy];

    [[NSNotificationCenter defaultCenter] postNotificationName:ICLabelFontDidChange object:self];
}

- (void)setFontSize:(CGFloat)fontSize
{
    _fontSize = fontSize;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ICLabelFontDidChange object:self];    
}

- (icColor4B)color
{
    // FIXME: implement color
    return (icColor4B){0,0,0,0};
}

- (void)setColor:(icColor4B)color
{
    // FIXME: implement color
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
    [self.textFrame setUserInteractionEnabled:userInteractionEnabled];
}

+ (NSAttributedString *)attributedTextWithText:(NSString *)text font:(ICFont *)font
{
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, ICFontAttributeName, nil];
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text
                                                                         attributes:attributes];
    return [attributedText autorelease];
}

+ (void)measureTextForAutoresizing:(NSString *)text font:(ICFont *)font origin:(kmVec3 *)origin size:(kmVec3 *)size
{
    // Measure each text line contained in text
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSMutableArray *textLines = [NSMutableArray arrayWithCapacity:[lines count]];
    for (NSString *line in lines) {
        ICTextLine *textLine = [ICTextLine textLineWithString:line font:font];
        [textLines addObject:textLine];
    }
    
    kmAABB aabb = icComputeAABBContainingAABBsOfNodes(textLines);
    if (origin) {
        *origin = aabb.min;
    }
    if (size) {
        *size = kmVec3Make(aabb.max.x - aabb.min.x,
                           aabb.max.y - aabb.min.y,
                           aabb.max.z - aabb.min.z);
    }
}

- (void)autoresizeToText
{
    kmVec3 origin, size;
    ICFont *font = [ICFont fontWithName:self.fontName size:self.fontSize];
    [[self class] measureTextForAutoresizing:self.text font:font origin:&origin size:&size];
    self.origin = origin;
    self.size = size;
}

- (void)updateFrame
{
    if (self.autoresizesToTextSize) {
        [self autoresizeToText];
    }
    
    if (!self.textFrame) {
        self.textFrame = [ICTextFrame textFrameWithSize:kmVec2Make(self.size.width, self.size.height)
                                       attributedString:self.attributedText];
        [self addChild:self.textFrame];
    } else {
        self.textFrame.size = self.size;
        self.textFrame.attributedString = self.attributedText;
    }
}

@end

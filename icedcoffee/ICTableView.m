//  
//  Copyright (C) 2013 Tobias Lensing, Marcus Tillmanns
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

#import "ICTableView.h"
#import "ICTableViewCell.h"

@implementation ICTableView

@synthesize dataSource = _dataSource;

- (id)initWithSize:(kmVec3)size
{
    if ((self = [super initWithSize:size])) {
        _reusableCells = [[NSMutableDictionary alloc] initWithCapacity:1];
    }
    return self;
}

- (void)dealloc
{
    [_reusableCells release];
    _reusableCells = nil;
    
    [super dealloc];
}

- (void)setDataSource:(id<ICTableViewDataSource>)dataSource
{
    _dataSource = dataSource;
    [self reloadData]; 
}

- (ICTableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
    return nil;
}

- (void)reloadData
{
    if (_dataSource) {
        NSInteger numRows = [_dataSource numberOfRowsInTableView:self];
        for (NSInteger i=0; i<numRows; i++) {
            ICTableViewCell *cell = [_dataSource tableView:self cellForRowAtIndex:i];
            [self addChild:cell];
            [cell setPositionY:i * cell.size.height];
            [cell setSize:kmVec3Make(self.size.width, cell.size.height, 0)];
        }
        [self setNeedsDisplay];
    }
}

@end

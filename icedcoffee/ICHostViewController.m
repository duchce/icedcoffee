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

#import "ICHostViewController.h"
#import "icDefaults.h"
#import "ICScene.h"
#import "ICRenderTexture.h"
#import "ICTextureCache.h"
#import "ICScheduler.h"
#import "ICCamera.h"
#import "ICRenderContext.h"
#import "ICContextManager.h"
#import "ICTargetActionDispatcher.h"
#import "icDefaults.h"
#import "icConfig.h"
#import "sys/time.h"

// Global content scale factor (applies to all ICHostViewController instances)
float g_icContentScaleFactor = IC_DEFAULT_CONTENT_SCALE_FACTOR;

// Globally current host view controller
ICHostViewController *g_currentHostViewController = nil;


@interface ICHostViewController (Private)
- (void)setScene:(ICScene *)scene;
- (void)setIsRunning:(BOOL)isRunning;
- (void)setViewSize:(CGSize)viewSize;
@end


// FIXME: render contexts must be shared if host view's OpenGL context is shared
@implementation ICHostViewController

@synthesize scene = _scene;
@synthesize isRunning = _isRunning;
@synthesize thread = _thread;
@synthesize currentFirstResponder = _currentFirstResponder;
@synthesize scheduler = _scheduler;
@synthesize targetActionDispatcher = _targetActionDispatcher;
@synthesize frameUpdateMode = _frameUpdateMode;

+ (ICHostViewController *)platformSpecificHostViewController
{
    return [[[IC_HOSTVIEWCONTROLLER alloc] init] autorelease];
}

- (id)init
{
    if ((self = [super init])) {
        _scheduler = [[ICScheduler alloc] init];        
        _targetActionDispatcher = [[ICTargetActionDispatcher alloc] init];
        _lastUpdate.tv_sec = 0;
        _lastUpdate.tv_usec = 0;
        _frameUpdateMode = ICFrameUpdateModeSynchronized;
        _needsDisplay = YES;
    }
    return [self makeCurrentHostViewController];
}

- (void)dealloc
{
#ifdef __IC_PLATFORM_MAC
    [[ICContextManager defaultContextManager]
     unregisterRenderContextForOpenGLContext:[[self view] openGLContext]];
#elif defined(__IC_PLATFORM_IOS)
    [[ICContextManager defaultContextManager]
     unregisterRenderContextForOpenGLContext:[((ICGLView *)[self view]) context]];
#endif
    
    self.scene = nil;
    [_currentFirstResponder release];
    [_scheduler release];
    [_renderContext release];
    [_targetActionDispatcher release];
    
    [super dealloc];
}

+ (ICHostViewController *)currentHostViewController
{
    ICHostViewController *currentHostViewController;
    @synchronized (self) {
        currentHostViewController = g_currentHostViewController;
    }
    return currentHostViewController;
}

- (id)makeCurrentHostViewController
{
    @synchronized (self) {
        g_currentHostViewController = self;
    }
    return self;
}

- (void)calculateDeltaTime
{
    @synchronized (self) {
        struct timeval now;
        if (gettimeofday(&now, NULL) != 0) {
            ICLog(@"IcedCoffee: error occurred in gettimeofday");
            _deltaTime = 0;
            return;
        }
        
        if (_lastUpdate.tv_sec == 0 && _lastUpdate.tv_usec == 0) {
            _deltaTime = 0;
        } else {
            _deltaTime = (now.tv_sec - _lastUpdate.tv_sec) + (now.tv_usec - _lastUpdate.tv_usec) / 1000000.0f;
            _deltaTime = MAX(0, _deltaTime);
        }
        
        _lastUpdate = now;
    }
}

- (void)setNeedsDisplay
{
    _needsDisplay = YES;
}

- (void)drawScene
{
    // Override in subclass, call base implementation before drawing
    
    // Make the receiver the current host view controller before drawing the scene
    [self makeCurrentHostViewController];
}

- (void)runWithScene:(ICScene *)scene
{
    self.scene = scene;
    scene.hostViewController = self;
    [self startAnimation];
}

- (void)startAnimation
{
    // Override in subclass
}

- (void)stopAnimation
{
    // Override in subclass
}

- (void)reshape:(CGSize)newViewSize
{
    // Adjust the root scene to the new size of the host view
    [self.scene setSize:kmVec3Make(newViewSize.width, newViewSize.height, 0)];
}

- (void)setView:(ICGLView *)view
{
#ifdef __IC_PLATFORM_IOS
    [super setView:view];
#endif
    // Mac host view controller implements this in its own subclass
    
    // OpenGL context became available: if the view's OpenGL context doesn't have a corresponding
    // render context yet, create and register a new render context for it, so it's possible
    // for other components to retrieve it via the OpenGL context globally
    ICContextManager *contextManager = [ICContextManager defaultContextManager];
    _renderContext = [contextManager renderContextForOpenGLContext:[self openGLContext]];
    if (!_renderContext) {
        _renderContext = [[ICRenderContext alloc] init];
        [contextManager registerRenderContext:_renderContext
                             forOpenGLContext:[self openGLContext]];
    }
    
    // If not already existing, create a texture cache bound to our OpenGL context
    // (required for auxiliary OpenGL context)
    if (!self.textureCache) {
        _renderContext.textureCache = 
            [[[ICTextureCache alloc] initWithHostViewController:self] autorelease];
    }
}

#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
- (ICGLView *)view
{
    // Must be overriden in Mac host view controller
    return nil;
}
#endif

#ifdef __IC_PLATFORM_IOS
- (EAGLContext *)openGLContext
{
    return [(ICGLView *)[self view] context];
}
#elif defined(__IC_PLATFORM_MAC)
- (NSOpenGLContext *)openGLContext
{
    return [[self view] openGLContext];
}
#endif

- (void)setCurrentFirstResponder:(ICResponder *)currentFirstResponder
{
    [_currentFirstResponder resignFirstResponder];
    [_currentFirstResponder release];
    _currentFirstResponder = [currentFirstResponder retain];
    [_currentFirstResponder becomeFirstResponder];
}

- (float)contentScaleFactor
{
    return g_icContentScaleFactor;
}

- (void)setContentScaleFactor:(float)contentScaleFactor
{
    g_icContentScaleFactor = contentScaleFactor;
}

- (BOOL)retinaDisplaySupportEnabled
{
    return _retinaDisplayEnabled;
}

- (BOOL)enableRetinaDisplaySupport:(BOOL)retinaDisplayEnabled
{
#ifdef __IC_PLATFORM_IOS
    if (![[self view] respondsToSelector:@selector(setContentScaleFactor:)]) {
        return NO; // setContentScaleFactor not supported by software 
    }
    
	if ([[UIScreen mainScreen] scale] == 1.0)
		return NO; // SD device

    _retinaDisplayEnabled = retinaDisplayEnabled;
    [self setContentScaleFactor:retinaDisplayEnabled ? IC_DEFAULT_RETINA_CONTENT_SCALE_FACTOR
                                : IC_DEFAULT_CONTENT_SCALE_FACTOR];
    
    [[self view] setContentScaleFactor:[self contentScaleFactor]];
    return YES;
#else
    // Retina display not supported on other platforms
    return NO;
#endif
}

- (ICTextureCache *)textureCache
{
    return _renderContext.textureCache;
}


#ifdef __IC_PLATFORM_MAC

- (void)setCursor:(NSCursor *)cursor
{
    [(ICGLView *)[self view] setCursor:cursor];
}

#endif // __IC_PLATFORM_MAC


- (CGSize)frameBufferSize
{
    return [[self view] bounds].size;
}


// Private

- (void)setIsRunning:(BOOL)isRunning
{
    _isRunning = isRunning;
}

- (NSArray *)hitTest:(CGPoint)point
{
    // Override in subclass
    return nil;
}


@end

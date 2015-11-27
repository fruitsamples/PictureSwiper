/*
     File: SlideShowSwipeController.m 
 Abstract: This view controller controls how images are swiped back and forth with a slide-show style serialized layout. 
  Version: 1.0 
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2011 Apple Inc. All Rights Reserved. 
  
 */

#import "SlideShowSwipeController.h"
#import "MagnifyingLayerView.h"
#import <QuartzCore/QuartzCore.h>

/*  The visuals of a fluid swipe are accomplished via an overlay layerbacked view.
    For performance, we create the overlay view and setup the layers immediatly,
    but set the overlay view to hidden. It is faster to show a hidden view than it
    is to create one on fly. This is a noticeable difference in responsiveness of the
    beginning of a fluid swipe.
*/

const NSInteger slideShowContentChangedContext = 102776;

@interface SlideShowSwipeController ()
@property(retain) NSBox *swipeLayerView;

- (void)createLayers;
- (void)moveOverlayContentTo:(CGFloat)offset;
- (void)updateLayersCache;
- (CALayer *)rootLayer;

- (void)showSwipeOverlay;
- (void)hideSwipeOverlay;
@end

@implementation SlideShowSwipeController

@synthesize contentView;
@synthesize swipeLayerView;

- (void)setContentView:(MagnifyingLayerView *)newContentView {
    if (self->contentView != newContentView) {
        if (self->contentView) {
            [self.contentView removeObserver:self forKeyPath:@"content" context:(void*)&slideShowContentChangedContext];
            [[self.contentView enclosingScrollView] setNextResponder:[self nextResponder]];
            [self setNextResponder:nil];
        }
        
        if (self.swipeLayerView) {
            [self.swipeLayerView removeFromSuperviewWithoutNeedingDisplay];
            self.swipeLayerView = nil;
        }
        
        self->contentView = [newContentView retain];
        
        if (newContentView) {
            [self setNextResponder:[[newContentView enclosingScrollView] nextResponder]];
            [[newContentView enclosingScrollView] setNextResponder:self];

            // The base of our overlay view is an NSBox so that we can set a background color
            NSBox *boxView = [[NSBox alloc] initWithFrame:self.contentView.frame];
            [boxView setBorderType:NSNoBorder];
            [boxView setBoxType:NSBoxCustom];
            [boxView setContentViewMargins:NSMakeSize(0, 0)];
            [boxView setHidden:YES];
            boxView.autoresizingMask = self.contentView.autoresizingMask;

            // This is the layer backed view where we will do all the CALayer animation
            NSView *layerView = [[NSView alloc] initWithFrame:boxView.bounds];
            layerView.autoresizingMask = boxView.autoresizingMask;
            layerView.wantsLayer = YES;
            layerView.layer = [CALayer layer];
            [boxView setContentView:[layerView autorelease]];

            // Set our Hidden overlay view hierarcy as a sibling to the enclosing scroll view
            [[[self.contentView enclosingScrollView] superview] addSubview:boxView];
            self.swipeLayerView = [boxView autorelease];

            [self createLayers];

            // Use KVO to observe when the contentView content changes so we can update our layer cache.
            [self.contentView addObserver:self forKeyPath:@"content" options:0 context:(void*)&slideShowContentChangedContext];
            [self updateLayersCache];
        }
    }
}

- (void)dealloc {
    self.contentView = nil;
    [super dealloc];
}

- (BOOL)wantsScrollEventsForSwipeTrackingOnAxis:(NSEventGestureAxis)axis {
    // Inform the underlying scroll view that we want horizontal scroll gesture events for fluid swiping
    return (axis == NSEventGestureAxisHorizontal) ? YES : NO;
}

- (void)scrollWheel:(NSEvent *)event {
    // if we have to hide the overlay view because a second swipe came in before the animation completed,
    // then there will be a visual blip as the overlay view hides, and is shown again during the next tracking.
    // Disabeling screen updates here prevent that blip.
    //
    NSDisableScreenUpdates();
    
    // An ivar (swipeAnimationCancelled) is used here so that we can cancel an outstanding swipe tracking if
    // another swipe comes in before the current one completes. This can happen because the swipe tracking
    // block continues afer the physical swipe completes.
    //
    if (swipeAnimationCancelled && *swipeAnimationCancelled == NO) {
        *swipeAnimationCancelled = YES;
        swipeAnimationCancelled = NULL;
        
        // We don't know when the existing block will get called back and can check it's cancelled flag, so hide the swipe overlay now
        [self hideSwipeOverlay];
    }
    
    MagnifyingLayerView *magnifyingLayerView = self.contentView;
    id <MagnifyingLayerViewDelegate> delegate = magnifyingLayerView.delegate;
    
    CGFloat backItemCount = -[delegate minimumOffsetForMagnifyingLayerView:magnifyingLayerView];
    CGFloat forwardItemCount = [delegate maximumOffsetForMagnifyingLayerView:magnifyingLayerView];
    
    __block BOOL animationCancelled = NO;
    __block id newContent = magnifyingLayerView.content;
    [event trackSwipeEventWithOptions:0 dampenAmountThresholdMin:-forwardItemCount max:backItemCount usingHandler:^(CGFloat gestureAmount, NSEventPhase phase, BOOL isComplete, BOOL *stop) {
        if (animationCancelled) {
            // We externally (to the block) cancelled tracking this swipe because another swipe has started before this one finished animating. Set *stop to YES to tell AppKit to stop calling back this block instance.
            *stop = YES; 
            return;
        } 
        
        if (phase == NSEventPhaseBegan) {
            [self showSwipeOverlay];
        }
        
        [self moveOverlayContentTo:gestureAmount];
        
        if (phase == NSEventPhaseEnded) {
            // gesture succeeded. Update the content view now.
            newContent = [delegate magnifyingLayerView:magnifyingLayerView contentAtOffsetIndex:(gestureAmount > 0) ? -1 : 1];
            self.contentView.content = newContent;
        } else if (phase == NSEventPhaseCancelled) {
            // gesture failed, don't update the content view
        }
        
        if (isComplete) {
            // Better hide the swipe overlay now because this is the last time this block instance will be called.
            [self hideSwipeOverlay];
            self->swipeAnimationCancelled = NULL;
        }
    }];
    
    // Set our ivar so that we know that swipe tracking is in progress and so we can cancel it if needed.
    self->swipeAnimationCancelled = &animationCancelled;
    
    // see NSDisableScreenUpdates above.
    NSEnableScreenUpdates();
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &slideShowContentChangedContext) {
        // Don't update the cache if we are currently swiping.
        if (!self->swipeAnimationCancelled) {
            [self updateLayersCache];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)createLayers {
    // For this style of swiping we need 5 layers. Remember, the gestureAmount of swipe can exceed +-1.
    // We will need to show previous and forward images outside of that range. With 5 layers we get 2
    // previous images, the current image, and 3 forward images. We use the zPos of the layer to act
    // as an offset index. [-2..2]
    // 
    // Dealing with gesture amounts outside of the range +-2 is left as an excersise for the reader.
    //
    CALayer *rootLayer = [self rootLayer];
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSInteger zPos = -2; zPos <= 2; zPos++) {
        CALayer *layer = [CALayer layer];
        layer.zPosition = zPos;
        layer.frame = rootLayer.bounds; // don't worry about the exact frame yet.
        layer.anchorPoint = CGPointMake(0, 0);
        layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
        layer.contentsGravity = kCAGravityResizeAspect;
        [rootLayer addSublayer:layer];
    }
    [CATransaction commit];
}

- (void)moveOverlayContentTo:(CGFloat)offset {
    CALayer *rootLayer = [self rootLayer];
    CGFloat layerWidth = rootLayer.bounds.size.width;
    
    offset *= layerWidth;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in [rootLayer sublayers]) {
        CGFloat xPosition = (layer.zPosition * layerWidth) + offset;
        layer.position = CGPointMake(xPosition, 0);
    }
    [CATransaction commit];
    
}

- (void)updateLayersCache {
    
    // We cache the layer contents to minimize the delay between the user's physical start of the swipe
    // and seeing something happened on screen (responsiveness). This costs us some memory, but swiping
    // is very performant sensitive.
    //
    // For the previous and forward layers, we can use the raw image because anytime the content is replaced,
    // the zoom factor is reset. The current layer needs to match the screen taking the zoom factor and scroll
    //  position into account. We do that in the cacheViewSnapshot.
    //
    CALayer *rootLayer = [self rootLayer];
    id <MagnifyingLayerViewDelegate> delegate = self.contentView.delegate;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.swipeLayerView setFillColor:self.contentView.backgroundColor];

    for (CALayer *layer in [rootLayer sublayers]) {
        NSInteger offset = layer.zPosition;
        if (offset != 0) {
            layer.contents = [delegate magnifyingLayerView:self.contentView contentAtOffsetIndex:offset];
        }
    }
    [CATransaction commit];
}

- (CALayer *)rootLayer {
    return [[self.swipeLayerView contentView] layer];
}

- (void)cacheViewSnapshot {
    // The actual content in the scroll view may be zoomed and scrolled around.
    // We need our layer to match exactly what is on the screen. This method sets the layer contents
    // that represent what is on the screen to match what is on the screen.
    //
    CALayer *rootLayer = [self rootLayer];
    NSImage *snapshot = [self.contentView snapshotImageForVisibleRect];
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in [rootLayer sublayers]) {
        if (layer.zPosition == 0) {
            layer.contents = snapshot;
            break;
        }
    }
    [CATransaction commit];
}

- (void)showSwipeOverlay {
    [self cacheViewSnapshot];
    [self moveOverlayContentTo:0];
    [self.swipeLayerView setHidden:NO];
}

- (void)hideSwipeOverlay {
    NSDisableScreenUpdates();
    [self.swipeLayerView setHidden:YES];
    [self.contentView displayIfNeeded];
    NSEnableScreenUpdates();
    
    // we likely need to update the cache
    [self updateLayersCache];
}

@end

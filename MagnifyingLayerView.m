/*
     File: MagnifyingLayerView.m 
 Abstract: Custom NSView subclass used for managing the image and background color. 
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

#import "MagnifyingLayerView.h"
#import <QuartzCore/QuartzCore.h>


@implementation MagnifyingLayerView

@synthesize content;
@synthesize delegate;
@synthesize backgroundColor;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setAutoresizesSubviews:YES];
        imageView = [[NSImageView alloc] initWithFrame:[self bounds]];
        [imageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [imageView setEditable:NO];
        [imageView setImageFrameStyle:NSImageFrameNone];
        [self addSubview:imageView];
        scale = 1.0;
    }
    return self;
}

- (void)dealloc {
    [content release];
    [backgroundColor release];
    [imageView release];
    
    [super dealloc];
}

- (void)awakeFromNib {
    self.backgroundColor = [NSColor grayColor];
}

- (void)setBackgroundColor:(NSColor *)newBackgroundColor {
    if (newBackgroundColor != backgroundColor) {
        [backgroundColor release];
        backgroundColor = [newBackgroundColor copy];
    }
    
    [[self enclosingScrollView] setBackgroundColor:newBackgroundColor];
}

- (BOOL)isOpaque {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [self.backgroundColor set];
    NSRectFill(dirtyRect);
}

- (void)setContent:(id)newContent {
    scale = 1.0;
    NSRect frame = {NSZeroPoint, [[self enclosingScrollView] bounds].size};
    [self setFrame:frame];
    [imageView setImage:newContent];
    
    origSize = frame.size;
    
    [content release];
    content = [newContent retain];
}

// return the visible part of the image, which will be used for the swipe animation
//
- (NSImage *)snapshotImageForVisibleRect {
    NSScrollView *sv = [self enclosingScrollView];
    NSRect visRect = [sv documentVisibleRect];
    NSBitmapImageRep *bitmapImageRep = [self bitmapImageRepForCachingDisplayInRect:visRect];
    bzero([bitmapImageRep bitmapData], [bitmapImageRep bytesPerRow] * [bitmapImageRep pixelsHigh]);
    [self cacheDisplayInRect:visRect toBitmapImageRep:bitmapImageRep];
    NSImage *imageCache = [[NSImage alloc] initWithSize:[bitmapImageRep size]];
    [imageCache addRepresentation:bitmapImageRep];
    
    return [imageCache autorelease];
}

// This event method will only be sent by hardware capable of generating the magnify gesture (i.e. TrackPad and Magic Mouse)
//
- (void)magnifyWithEvent:(NSEvent *)event {
    if (event.type == NSEventTypeMagnify) {
        __block id bMonitorID;
        id monitorID = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskEndGesture|NSEventMaskMagnify handler:^(NSEvent *monitorEvent) {
            if (monitorEvent.type == NSEventTypeMagnify) {
                NSSize size = [self frame].size;
                NSSize originalSize = size;
                
                size.height = floor(size.height * ([monitorEvent magnification] + 1.0));
                size.width = floor(size.width * ([monitorEvent magnification] + 1.0));
                
                if (size.width >= origSize.width && size.height >= origSize.height)
                {
                    // don't allow zooming smaller than the original photo size
                    [self setFrameSize:size];
                    CGFloat deltaX = (originalSize.width - size.width) / 2;
                    CGFloat deltaY = (originalSize.height - size.height) / 2;
                    NSPoint origin = self.frame.origin;
                    origin.x = origin.x + deltaX;
                    origin.y = origin.y + deltaY;
                    [self setFrameOrigin:origin];
                }
                monitorEvent = nil;
            } else if (monitorEvent.type == NSEventTypeEndGesture) {
                if ([monitorEvent subtype] == 8) {
                    monitorEvent = nil;
                    [NSEvent removeMonitor:bMonitorID];
                }
            }

            return monitorEvent;
        }];
        bMonitorID = monitorID;
    } 
}

@end


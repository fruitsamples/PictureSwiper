/*
     File: PictureSwiperAppDelegate.m 
 Abstract: The NSApplication delegate class used for loading the images and managing app's main window. 
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

#import "PictureSwiperAppDelegate.h"

@implementation PictureSwiperAppDelegate

@synthesize window;
@synthesize magnifyingLayerView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSURL *dirURL = [[NSBundle mainBundle] resourceURL];
    
    // load all the necessary image files by enumerating through the bundle's Resources folder,
    // this will only load images of type "kUTTypeImage"
    //
    data = [[NSMutableArray alloc] initWithCapacity:1];
    NSDirectoryEnumerator *itr = [[NSFileManager defaultManager] enumeratorAtURL:dirURL includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLLocalizedNameKey, NSURLEffectiveIconKey, NSURLIsDirectoryKey, NSURLTypeIdentifierKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
    
    for (NSURL *url in itr) {
        NSString *utiValue;
        [url getResourceValue:&utiValue forKey:NSURLTypeIdentifierKey error:nil];
        
        if (UTTypeConformsTo((CFStringRef)utiValue, kUTTypeImage)) {
            NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
            [data addObject:image];
            [image release];
        }
    }
    
    // set the first image in our list to the main magnifying view
    magnifyingLayerView.content = [data objectAtIndex:0];
}

- (void)dealloc {
    [data release];
    
    [super dealloc];
}

- (id)magnifyingLayerView:(MagnifyingLayerView *)mv contentAtOffsetIndex:(NSInteger)offset {
    NSInteger idx = [data indexOfObject:mv.content];
    if (idx == NSNotFound)
        idx = -1;
    idx += offset;
    if (idx >= 0 && idx < [data count]) {
        return [data objectAtIndex:idx];
    }
    
    return nil;
}

// determines how many forward images exist to the right
- (NSInteger)maximumOffsetForMagnifyingLayerView:(MagnifyingLayerView *)mv {
    NSInteger idx = [data indexOfObject:mv.content];
    if (idx == NSNotFound) return 0;
    
    return ([data count] - idx) - 1;
}

// determines how many backward images exist to the left
- (NSInteger)minimumOffsetForMagnifyingLayerView:(MagnifyingLayerView *)mv {
    NSInteger idx = [data indexOfObject:mv.content];
    if (idx == NSNotFound) return 0;
    
    return -idx;
}

@end

### PictureSwiper ###

================================================================================
DESCRIPTION:

Demonstrates how to use the swipe gesture to slide images in and out of view. It tracks scrolling to perform a fluid swipe animation for its image content.  The slide or swipe effect can be either in a serialized layout or in a stacked formation.

The sample implements in it's custom view -
	- (void)magnifyWithEvent:(NSEvent *)event;
This event method will only be sent by hardware capable of generating the magnify gesture (i.e. TrackPad and Magic Mouse)

It also implements -
	- (void)scrollWheel:(NSEvent *)theEvent;
Which takes into account the mouse’s scroll wheel has moved.

Fluid Swiping
This sample overrides and returns YES for:
	- (BOOL)wantsScrollEventsForSwipeTrackingOnAxis:(NSEventGestureAxis)axis;
This informs the underlying scroll view that we want horizontal scroll gesture events for fluid swiping.

The visuals of a fluid swipe are accomplished via an overlay layer-backed view. For performance, the sample creates the overlay view and setup the layers immediately, but set the overlay view to hidden. It is faster to show a hidden view than it is to create one on fly. This is a noticeable difference in responsiveness of the beginning of a fluid swipe.

================================================================================
BUILD REQUIREMENTS:

Mac OS X Lion or later

================================================================================
RUNTIME REQUIREMENTS:

Mac OS X Lion or later

================================================================================
CHANGES FROM PREVIOUS VERSIONS:

Version 1.0
- First Version

================================================================================
Copyright (C) 2011 Apple Inc. All rights reserved.

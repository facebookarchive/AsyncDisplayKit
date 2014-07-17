/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <QuartzCore/QuartzCore.h>

@interface ASHighlightOverlayLayer : CALayer

/**
 @summary Initializes with CGRects for the highlighting, in the targetLayer's coordinate space.

 @desc This is the designated initializer.

 @param rects Array containing CGRects wrapped in NSValue.
 @param targetLayer The layer that the rects are relative to.  The rects will be translated to the receiver's coordinate space when rendering.
 */
- (id)initWithRects:(NSArray *)rects targetLayer:(id)targetLayer;

/**
 @summary Initializes with CGRects for the highlighting, in the receiver's coordinate space.

 @param rects Array containing CGRects wrapped in NSValue.
 */
- (id)initWithRects:(NSArray *)rects;

@property (atomic, strong) __attribute__((NSObject)) CGColorRef highlightColor;
@property (atomic, weak) CALayer *targetLayer;

@end

@interface CALayer (ASHighlightOverlayLayerSupport)

/**
 @summary Set to YES to indicate to a sublayer that this is where highlight overlay layers (for pressed states) should
 be added so that the highlight won't be clipped by a neighboring layer.
 */
@property (nonatomic, assign, setter=as_setAllowsHighlightDrawing:) BOOL as_allowsHighlightDrawing;

@end

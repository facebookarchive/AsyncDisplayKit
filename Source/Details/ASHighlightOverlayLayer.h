//
//  ASHighlightOverlayLayer.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASHighlightOverlayLayer : CALayer

/**
 @summary Initializes with CGRects for the highlighting, in the targetLayer's coordinate space.

 @desc This is the designated initializer.

 @param rects Array containing CGRects wrapped in NSValue.
 @param targetLayer The layer that the rects are relative to.  The rects will be translated to the receiver's coordinate space when rendering.
 */
- (instancetype)initWithRects:(NSArray<NSValue *> *)rects targetLayer:(nullable CALayer *)targetLayer;

/**
 @summary Initializes with CGRects for the highlighting, in the receiver's coordinate space.

 @param rects Array containing CGRects wrapped in NSValue.
 */
- (instancetype)initWithRects:(NSArray<NSValue *> *)rects;

@property (nullable, nonatomic, strong) __attribute__((NSObject)) CGColorRef highlightColor;
@property (nonatomic, weak) CALayer *targetLayer;

@end

@interface CALayer (ASHighlightOverlayLayerSupport)

/**
 @summary Set to YES to indicate to a sublayer that this is where highlight overlay layers (for pressed states) should
 be added so that the highlight won't be clipped by a neighboring layer.
 */
@property (nonatomic, assign, setter=as_setAllowsHighlightDrawing:) BOOL as_allowsHighlightDrawing;

@end

NS_ASSUME_NONNULL_END

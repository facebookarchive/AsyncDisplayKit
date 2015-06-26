/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutNode.h>

typedef NS_OPTIONS(NSUInteger, ASCenterLayoutNodeCenteringOptions) {
  /** The child is positioned in {0,0} relatively to the layout bounds */
  ASCenterLayoutNodeCenteringNone = 0,
  /** The child is centered along the X axis */
  ASCenterLayoutNodeCenteringX = 1 << 0,
  /** The child is centered along the Y axis */
  ASCenterLayoutNodeCenteringY = 1 << 1,
  /** Convenience option to center both along the X and Y axis */
  ASCenterLayoutNodeCenteringXY = ASCenterLayoutNodeCenteringX | ASCenterLayoutNodeCenteringY
};

typedef NS_OPTIONS(NSUInteger, ASCenterLayoutNodeSizingOptions) {
  /** The node will take up the maximum size possible */
  ASCenterLayoutNodeSizingOptionDefault,
  /** The node will take up the minimum size possible along the X axis */
  ASCenterLayoutNodeSizingOptionMinimumX = 1 << 0,
  /** The node will take up the minimum size possible along the Y axis */
  ASCenterLayoutNodeSizingOptionMinimumY = 1 << 1,
  /** Convenience option to take up the minimum size along both the X and Y axis */
  ASCenterLayoutNodeSizingOptionMinimumXY = ASCenterLayoutNodeSizingOptionMinimumX | ASCenterLayoutNodeSizingOptionMinimumY,
};

/** Lays out a single child layout node and position it so that it is centered into the layout bounds. */
@interface ASCenterLayoutNode : ASLayoutNode

/**
 @param centeringOptions, see ASCenterLayoutNodeCenteringOptions.
 @param child The child to center.
 */
+ (instancetype)newWithCenteringOptions:(ASCenterLayoutNodeCenteringOptions)centeringOptions
                          sizingOptions:(ASCenterLayoutNodeSizingOptions)sizingOptions
                                  child:(id<ASLayoutable>)child;

@end

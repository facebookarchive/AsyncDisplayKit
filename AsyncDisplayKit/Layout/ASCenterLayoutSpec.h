/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutSpec.h>

/** How the child is centered within the spec. */
typedef NS_OPTIONS(NSUInteger, ASCenterLayoutSpecCenteringOptions) {
  /** The child is positioned in {0,0} relatively to the layout bounds */
  ASCenterLayoutSpecCenteringNone = 0,
  /** The child is centered along the X axis */
  ASCenterLayoutSpecCenteringX = 1 << 0,
  /** The child is centered along the Y axis */
  ASCenterLayoutSpecCenteringY = 1 << 1,
  /** Convenience option to center both along the X and Y axis */
  ASCenterLayoutSpecCenteringXY = ASCenterLayoutSpecCenteringX | ASCenterLayoutSpecCenteringY
};

/** How much space the spec will take up. */
typedef NS_OPTIONS(NSUInteger, ASCenterLayoutSpecSizingOptions) {
  /** The spec will take up the maximum size possible */
  ASCenterLayoutSpecSizingOptionDefault,
  /** The spec will take up the minimum size possible along the X axis */
  ASCenterLayoutSpecSizingOptionMinimumX = 1 << 0,
  /** The spec will take up the minimum size possible along the Y axis */
  ASCenterLayoutSpecSizingOptionMinimumY = 1 << 1,
  /** Convenience option to take up the minimum size along both the X and Y axis */
  ASCenterLayoutSpecSizingOptionMinimumXY = ASCenterLayoutSpecSizingOptionMinimumX | ASCenterLayoutSpecSizingOptionMinimumY,
};

/** Lays out a single layoutable child and position it so that it is centered into the layout bounds. */
@interface ASCenterLayoutSpec : ASLayoutSpec

/**
 * Initializer.
 *
 * @param centeringOptions How the child is centered.
 *
 * @param sizingOptions How much space will be taken up.
 *
 * @param child The child to center.
 */
+ (instancetype)newWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                          sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                  child:(id<ASLayoutable>)child;

@end

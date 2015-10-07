/*
 *  Copyright (c) 2015-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

/** The direction children are stacked in */
typedef NS_ENUM(NSUInteger, ASStackLayoutDirection) {
  /** Children are stacked vertically */
  ASStackLayoutDirectionVertical,
  /** Children are stacked horizontally */
  ASStackLayoutDirectionHorizontal,
};

/** If no children are flexible, how should this spec justify its children in the available space? */
typedef NS_ENUM(NSUInteger, ASStackLayoutJustifyContent) {
  /**
   On overflow, children overflow out of this spec's bounds on the right/bottom side.
   On underflow, children are left/top-aligned within this spec's bounds.
   */
  ASStackLayoutJustifyContentStart,
  /**
   On overflow, children are centered and overflow on both sides.
   On underflow, children are centered within this spec's bounds in the stacking direction.
   */
  ASStackLayoutJustifyContentCenter,
  /**
   On overflow, children overflow out of this spec's bounds on the left/top side.
   On underflow, children are right/bottom-aligned within this spec's bounds.
   */
  ASStackLayoutJustifyContentEnd,
};

/** Orientation of children along cross axis */
typedef NS_ENUM(NSUInteger, ASStackLayoutAlignItems) {
  /** Align children to start of cross axis */
  ASStackLayoutAlignItemsStart,
  /** Align children with end of cross axis */
  ASStackLayoutAlignItemsEnd,
  /** Center children on cross axis */
  ASStackLayoutAlignItemsCenter,
  /** Expand children to fill cross axis */
  ASStackLayoutAlignItemsStretch,
  /** Children align to their first baseline. Only available for horizontal stack spec */
  ASStackLayoutAlignItemsBaselineFirst,
  /** Children align to their last baseline. Only available for horizontal stack spec */
  ASStackLayoutAlignItemsBaselineLast,
};

/**
 Each child may override their parent stack's cross axis alignment.
 @see ASStackLayoutAlignItems
 */
typedef NS_ENUM(NSUInteger, ASStackLayoutAlignSelf) {
  /** Inherit alignment value from containing stack. */
  ASStackLayoutAlignSelfAuto,
  /** Align to start of cross axis */
  ASStackLayoutAlignSelfStart,
  /** Align with end of cross axis */
  ASStackLayoutAlignSelfEnd,
  /** Center on cross axis */
  ASStackLayoutAlignSelfCenter,
  /** Expand to fill cross axis */
  ASStackLayoutAlignSelfStretch,
};

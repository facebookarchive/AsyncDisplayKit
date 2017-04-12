//
//  ASStackLayoutDefines.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASBaseDefines.h>

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
  /**
   On overflow or if the stack has only 1 child, this value is identical to ASStackLayoutJustifyContentStart.
   Otherwise, the starting edge of the first child is at the starting edge of the stack, 
   the ending edge of the last child is at the ending edge of the stack, and the remaining children
   are distributed so that the spacing between any two adjacent ones is the same.
   If there is a remaining space after spacing division, it is combined with the last spacing (i.e the one between the last 2 children).
   */
  ASStackLayoutJustifyContentSpaceBetween,
  /**
   On overflow or if the stack has only 1 child, this value is identical to ASStackLayoutJustifyContentCenter.
   Otherwise, children are distributed such that the spacing between any two adjacent ones is the same,
   and the spacing between the first/last child and the stack edges is half the size of the spacing between children.
   If there is a remaining space after spacing division, it is combined with the last spacing (i.e the one between the last child and the stack ending edge).
   */
  ASStackLayoutJustifyContentSpaceAround
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
  ASStackLayoutAlignItemsNotSet
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

/** Whether children are stacked into a single or multiple lines. */
typedef NS_ENUM(NSUInteger, ASStackLayoutFlexWrap) {
  ASStackLayoutFlexWrapNoWrap,
  ASStackLayoutFlexWrapWrap,
};

/** Orientation of lines along cross axis if there are multiple lines. */
typedef NS_ENUM(NSUInteger, ASStackLayoutAlignContent) {
  ASStackLayoutAlignContentStart,
  ASStackLayoutAlignContentCenter,
  ASStackLayoutAlignContentEnd,
  ASStackLayoutAlignContentSpaceBetween,
  ASStackLayoutAlignContentSpaceAround,
  ASStackLayoutAlignContentStretch,
};

/** Orientation of children along horizontal axis */
typedef NS_ENUM(NSUInteger, ASHorizontalAlignment) {
  /** No alignment specified. Default value */
  ASHorizontalAlignmentNone,
  /** Left aligned */
  ASHorizontalAlignmentLeft,
  /** Center aligned */
  ASHorizontalAlignmentMiddle,
  /** Right aligned */
  ASHorizontalAlignmentRight,

  // After 2.0 has landed, we'll add ASDISPLAYNODE_DEPRECATED here - for now, avoid triggering errors for projects with -Werror
  /** @deprecated Use ASHorizontalAlignmentLeft instead */
  ASAlignmentLeft ASDISPLAYNODE_DEPRECATED = ASHorizontalAlignmentLeft,
  /** @deprecated Use ASHorizontalAlignmentMiddle instead */
  ASAlignmentMiddle ASDISPLAYNODE_DEPRECATED = ASHorizontalAlignmentMiddle,
  /** @deprecated Use ASHorizontalAlignmentRight instead */
  ASAlignmentRight ASDISPLAYNODE_DEPRECATED = ASHorizontalAlignmentRight,
};

/** Orientation of children along vertical axis */
typedef NS_ENUM(NSUInteger, ASVerticalAlignment) {
  /** No alignment specified. Default value */
  ASVerticalAlignmentNone,
  /** Top aligned */
  ASVerticalAlignmentTop,
  /** Center aligned */
  ASVerticalAlignmentCenter,
  /** Bottom aligned */
  ASVerticalAlignmentBottom,

  // After 2.0 has landed, we'll add ASDISPLAYNODE_DEPRECATED here - for now, avoid triggering errors for projects with -Werror
  /** @deprecated Use ASVerticalAlignmentTop instead */
  ASAlignmentTop ASDISPLAYNODE_DEPRECATED = ASVerticalAlignmentTop,
  /** @deprecated Use ASVerticalAlignmentCenter instead */
  ASAlignmentCenter ASDISPLAYNODE_DEPRECATED = ASVerticalAlignmentCenter,
  /** @deprecated Use ASVerticalAlignmentBottom instead */
  ASAlignmentBottom ASDISPLAYNODE_DEPRECATED = ASVerticalAlignmentBottom,
};

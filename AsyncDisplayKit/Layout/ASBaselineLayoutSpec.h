/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASLayoutable.h>

typedef NS_ENUM(NSUInteger, ASBaselineLayoutBaselineAlignment) {
  /** No baseline alignment. This is only valid for a vertical stack */
  ASBaselineLayoutBaselineAlignmentNone,
  /** Align all children to the first baseline. This is only valid for a horizontal stack */
  ASBaselineLayoutBaselineAlignmentFirst,
  /** Align all children to the last baseline. This is useful when a text node wraps and you want to align
   to the bottom baseline. This is only valid for a horizontal stack */
  ASBaselineLayoutBaselineAlignmentLast,
};

/**
 A specialized version of a stack layout that aligns its children on a baseline. This spec only works with
 ASBaselineLayoutable children. 
 
 If the spec is created with a horizontal direction, the children will be laid on a common baseline.
 If the spec is created with a vertical direction, a child's vertical spacing will be measured from its
 baseline instead of from the child's bounding box.
*/
@interface ASBaselineLayoutSpec : ASLayoutSpec

/** Specifies the direction children are stacked in. */
@property (nonatomic, assign) ASStackLayoutDirection direction;
/** The amount of space between each child. */
@property (nonatomic, assign) CGFloat spacing;
/** The amount of space between each child. */
@property (nonatomic, assign) ASStackLayoutJustifyContent justifyContent;
/** Orientation of children along cross axis */
@property (nonatomic, assign) ASStackLayoutAlignItems alignItems;
/** The type of baseline alignment */
@property (nonatomic, assign) ASBaselineLayoutBaselineAlignment baselineAlignment;

/**
 @param direction The direction of the stack view (horizontal or vertical)
 @param spacing The spacing between the children
 @param baselineAlignment The baseline to align to
 @param justifyContent If no children are flexible, this describes how to fill any extra space
 @param alignItems Orientation of the children along the cross axis
 @param children ASLayoutable children to be positioned.
 */
+ (instancetype)baselineLayoutSpecWithDirection:(ASStackLayoutDirection)direction
                                        spacing:(CGFloat)spacing
                              baselineAlignment:(ASBaselineLayoutBaselineAlignment)baselineAlignment
                                 justifyContent:(ASStackLayoutJustifyContent)justifyContent
                                     alignItems:(ASStackLayoutAlignItems)alignItems
                                       children:(NSArray *)children;

@end

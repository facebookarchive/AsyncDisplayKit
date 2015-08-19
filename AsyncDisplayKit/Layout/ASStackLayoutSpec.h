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
#import <AsyncDisplayKit/ASStackLayoutDefines.h>

typedef struct {
  /** Specifies the direction children are stacked in. */
  ASStackLayoutDirection direction;
  /** The amount of space between each child. */
  CGFloat spacing;
  /** How children are aligned if there are no flexible children. */
  ASStackLayoutJustifyContent justifyContent;
  /** Orientation of children along cross axis */
  ASStackLayoutAlignItems alignItems;
  /** 
   If YES the vertical spacing between two views is measured from the last baseline of the
   top view to the top of the bottom view*/
  BOOL baselineRelativeArrangement;
} ASStackLayoutSpecStyle;

/**
 A simple layout spec that stacks a list of children vertically or horizontally.

 - All children are initially laid out with the an infinite available size in the stacking direction.
 - In the other direction, this spec's constraint is passed.
 - The children's sizes are summed in the stacking direction.
   - If this sum is less than this spec's minimum size in stacking direction, children with flexGrow are flexed.
   - If it is greater than this spec's maximum size in the stacking direction, children with flexShrink are flexed.
   - If, even after flexing, the sum is still greater than this spec's maximum size in the stacking direction,
     justifyContent determines how children are laid out.

 For example:
 
 - Suppose stacking direction is Vertical, min-width=100, max-width=300, min-height=200, max-height=500.
 - All children are laid out with min-width=100, max-width=300, min-height=0, max-height=INFINITY.
 - If the sum of the childrens' heights is less than 200, children with flexGrow are flexed larger.
 - If the sum of the childrens' heights is greater than 500, children with flexShrink are flexed smaller.
   Each child is shrunk by `((sum of heights) - 500)/(number of flexShrink-able children)`.
 - If the sum of the childrens' heights is greater than 500 even after flexShrink-able children are flexed,
   justifyContent determines how children are laid out.
 */
@interface ASStackLayoutSpec : ASLayoutSpec

/**
 @param style Specifies how children are laid out.
 @param children ASLayoutable children to be positioned.
 */
+ (instancetype)newWithStyle:(ASStackLayoutSpecStyle)style children:(NSArray *)children;

@end

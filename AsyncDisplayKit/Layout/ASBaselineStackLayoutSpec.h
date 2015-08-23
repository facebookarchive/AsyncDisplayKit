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
#import <AsyncDisplayKit/ASBaselineStackLayoutable.h>

typedef NS_ENUM(NSUInteger, ASBaselineStackLayoutBaselineAlignment) {
  /** No baseline alignment. This is only valid for a vertical stack */
  ASBaselineStackLayoutBaselineAlignmentNone,
  /** Align all children to the first baseline. This is only valid for a horizontal stack */
  ASBaselineStackLayoutBaselineAlignmentFirst,
  /** Align all children to the last baseline. This is useful when a text node wraps and you want to align
   to the bottom baseline. This is only valid for a horizontal stack */
  ASBaselineStackLayoutBaselineAlignmentLast,
};


typedef struct {
  /** Describes how the stack will be laid out */
  ASStackLayoutSpecStyle stackLayoutStyle;
  
  /** The type of baseline alignment */
  ASBaselineStackLayoutBaselineAlignment baselineAlignment;
} ASBaselineStackLayoutSpecStyle;

/**
 A specialized version of a stack layout that aligns its children on a baseline. This spec only works with
 ASBaselineStackLayoutable children. 
 
 If the spec is created with a horizontal direction, the children will be laid on a common baseline.
 If the spec is created with a vertical direction, a child's vertical spacing will be measured from its
 baseline instead of from the child's bounding box.
*/
@interface ASBaselineStackLayoutSpec : ASLayoutSpec <ASBaselineStackLayoutable>

/**
 @param style Specifies how children are laid out.
 @param children ASTextLayoutable children to be positioned.
 */
+ (instancetype)newWithStyle:(ASBaselineStackLayoutSpecStyle)style children:(NSArray *)children;

@end

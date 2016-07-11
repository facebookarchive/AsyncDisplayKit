//
//  ASStackUnpositionedLayout.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <vector>

#import "ASLayout.h"
#import "ASStackLayoutSpecUtilities.h"
#import "ASStackLayoutSpec.h"

struct ASStackUnpositionedItem {
  /** The original source child. */
  id<ASLayoutable> child;
  /** The proposed layout. */
  ASLayout *layout;
};

/** Represents a set of stack layout children that have their final layout computed, but are not yet positioned. */
struct ASStackUnpositionedLayout {
  /** A set of proposed child layouts, not yet positioned. */
  const std::vector<ASStackUnpositionedItem> items;
  /** The total size of the children in the stack dimension, including all spacing. */
  const CGFloat stackDimensionSum;
  /** The amount by which stackDimensionSum violates constraints. If positive, less than min; negative, greater than max. */
  const CGFloat violation;

  /** Given a set of children, computes the unpositioned layouts for those children. */
  static ASStackUnpositionedLayout compute(const std::vector<id<ASLayoutable>> &children,
                                           const ASStackLayoutSpecStyle &style,
                                           const ASSizeRange &sizeRange);
};

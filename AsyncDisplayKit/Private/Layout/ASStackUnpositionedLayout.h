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

#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASStackLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASStackLayoutSpec.h>

struct ASStackLayoutSpecChild {
  /** The original source child. */
  id<ASLayoutElement> element;
  /** Style object of element. */
  ASLayoutElementStyle *style;
  /** Size object of the element */
  ASLayoutElementSize size;
};

struct ASStackLayoutSpecItem {
  /** The original source child. */
  ASStackLayoutSpecChild child;
  /** The proposed layout or nil if no is calculated yet. */
  ASLayout *layout;
};


/** Represents a set of stack layout children that have their final layout computed, but are not yet positioned. */
struct ASStackUnpositionedLayout {
  /** A set of proposed child layouts, not yet positioned. */
  const std::vector<ASStackLayoutSpecItem> items;
  /** The total size of the children in the stack dimension, including all spacing. */
  const CGFloat stackDimensionSum;
  /** The amount by which stackDimensionSum violates constraints. If positive, less than min; negative, greater than max. */
  const CGFloat violation;
  /** The size in the cross dimension */
  const CGFloat crossSize;
  /** The baseline of the stack which baseline aligned children should align to */
  const CGFloat baseline;
  
  /** Given a set of children, computes the unpositioned layouts for those children. */
  static ASStackUnpositionedLayout compute(const std::vector<ASStackLayoutSpecChild> &children,
                                           const ASStackLayoutSpecStyle &style,
                                           const ASSizeRange &sizeRange);
  
  static CGFloat baselineForItem(const ASStackLayoutSpecStyle &style,
                                 const ASStackLayoutSpecItem &l);
};

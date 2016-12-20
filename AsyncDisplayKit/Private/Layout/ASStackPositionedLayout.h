//
//  ASStackPositionedLayout.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASStackUnpositionedLayout.h>

/** Represents a set of laid out and positioned stack layout children. */
struct ASStackPositionedLayout {
  const std::vector<ASStackLayoutSpecItem> items;
  /** Final size of the stack */
  const CGSize size;
  
  /** Given an unpositioned layout, computes the positions each child should be placed at. */
  static ASStackPositionedLayout compute(const ASStackUnpositionedLayout &unpositionedLayout,
                                         const ASStackLayoutSpecStyle &style,
                                         const ASSizeRange &constrainedSize);
};

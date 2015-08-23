/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayout.h"
#import "ASDimension.h"
#import "ASBaselineStackLayoutSpec.h"
#import "ASStackPositionedLayout.h"

struct ASBaselineStackPositionedLayout {
    const std::vector<ASLayout *> sublayouts;
    const CGFloat crossSize;
    const CGFloat ascender;
    const CGFloat descender;
    
    /** Given a positioned layout, computes each child position using baseline alignment. */
    static ASBaselineStackPositionedLayout compute(const ASStackPositionedLayout &positionedLayout,
                                               const ASBaselineStackLayoutSpecStyle &style,
                                               const ASSizeRange &constrainedSize);
};

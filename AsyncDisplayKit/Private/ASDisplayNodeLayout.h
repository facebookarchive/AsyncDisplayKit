//
//  ASDisplayNodeLayout.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 08/26/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import "ASDimension.h"

@class ASLayout;

/*
 * Represents an ASLayout connected to a ASDisplayNode
 */
struct ASDisplayNodeLayout {
  ASLayout *layout;
  ASSizeRange constrainedSize;
  CGSize parentSize;
  BOOL _dirty;
  
  ASDisplayNodeLayout(ASLayout *layout, ASSizeRange constrainedSize, CGSize parentSize)
  : layout(layout), constrainedSize(constrainedSize), parentSize(parentSize), _dirty(NO) {};
  
  ASDisplayNodeLayout()
  : layout(nil), constrainedSize({{0, 0}, {0, 0}}), parentSize({0, 0}), _dirty(NO) {};
  
  BOOL isDirty() {
    return _dirty || layout == nil;
  }
  
  BOOL isValidForConstrainedSizeParentSize(ASSizeRange theConstrainedSize, CGSize theParentSize) {
    // Only generate a new layout if:
    // - The current layout is dirty
    // - The passed constrained size is different than the original layout's parent or constrained  size
    return (layout != nil
            && _dirty == NO
            && CGSizeEqualToSize(parentSize, theParentSize)
            && ASSizeRangeEqualToSizeRange(constrainedSize, theConstrainedSize));
  }
  
  void invalidate() {
    _dirty = YES;
  }
};

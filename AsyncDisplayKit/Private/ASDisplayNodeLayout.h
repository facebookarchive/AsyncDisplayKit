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

#import <AsyncDisplayKit/ASDimension.h>

@class ASLayout;

/*
 * Represents a connection between an ASLayout and a ASDisplayNode
 * ASDisplayNode uses this to store additional information that are necessary besides the layout
 */
struct ASDisplayNodeLayout {
  ASLayout *layout;
  ASSizeRange constrainedSize;
  CGSize parentSize;
  BOOL requestedLayoutFromAbove;
  BOOL _dirty;
  
  /*
   * Create a new display node layout with
   * @param layout The layout to associate, usually returned from a call to -layoutThatFits:parentSize:
   * @param constrainedSize Constrained size used to create the layout
   * @param parentSize Parent size used to create the layout
   */
  ASDisplayNodeLayout(ASLayout *layout, ASSizeRange constrainedSize, CGSize parentSize)
  : layout(layout), constrainedSize(constrainedSize), parentSize(parentSize), requestedLayoutFromAbove(NO), _dirty(NO) {};
  
  /*
   * Creates a layout without any layout associated. By default this display node layout is dirty.
   */
  ASDisplayNodeLayout()
  : layout(nil), constrainedSize({{0, 0}, {0, 0}}), parentSize({0, 0}), requestedLayoutFromAbove(NO), _dirty(YES) {};
  
  /**
   * Returns if the display node layout is dirty as it was invalidated or it was created without a layout.
   */
  BOOL isDirty();
  
  /**
   * Returns if ASDisplayNode is still valid for a given constrained and parent size
   */
  BOOL isValidForConstrainedSizeParentSize(ASSizeRange constrainedSize, CGSize parentSize);
  
  /**
   * Invalidate the display node layout
   */
  void invalidate();
};

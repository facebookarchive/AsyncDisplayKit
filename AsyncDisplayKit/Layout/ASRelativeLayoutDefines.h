//
//  ASRelativeLayoutSpec.h
//  AsyncDisplayKit
//
//  Created by Samuel Stow on 12/31/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//


/** How the child is positioned within the spec. */
typedef NS_OPTIONS(NSUInteger, ASRelativeLayoutSpecPosition) {
  /** The child is positioned at point 0 relatively to the layout axis (ie left / top most) */
  ASRelativeLayoutSpecPositionStart = 0,
  /** The child is centered along the specified axis */
  ASRelativeLayoutSpecPositionCenter = 1 << 0,
  /** The child is positioned at the maximum point of the layout axis (ie right / bottom most) */
  ASRelativeLayoutSpecPositionEnd = 1 << 1,
};

/** How much space the spec will take up. */
typedef NS_OPTIONS(NSUInteger, ASRelativeLayoutSpecSizingOption) {
  /** The spec will take up the maximum size possible */
  ASRelativeLayoutSpecSizingOptionDefault,
  /** The spec will take up the minimum size possible along the X axis */
  ASRelativeLayoutSpecSizingOptionMinimumWidth = 1 << 0,
  /** The spec will take up the minimum size possible along the Y axis */
  ASRelativeLayoutSpecSizingOptionMinimumHeight = 1 << 1,
  /** Convenience option to take up the minimum size along both the X and Y axis */
  ASRelativeLayoutSpecSizingOptionMinimumSize = ASRelativeLayoutSpecSizingOptionMinimumWidth | ASRelativeLayoutSpecSizingOptionMinimumHeight,
};
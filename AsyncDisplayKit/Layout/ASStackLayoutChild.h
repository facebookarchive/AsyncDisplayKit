/*
 *  Copyright (c) 2015-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

/**
 Each child may override their parent stack's cross axis alignment.
 @see ASStackLayoutAlignItems
 */
typedef NS_ENUM(NSUInteger, ASStackLayoutAlignSelf) {
  /** Inherit alignment value from containing stack. */
  ASStackLayoutAlignSelfAuto,
  ASStackLayoutAlignSelfStart,
  ASStackLayoutAlignSelfEnd,
  ASStackLayoutAlignSelfCenter,
  ASStackLayoutAlignSelfStretch,
};

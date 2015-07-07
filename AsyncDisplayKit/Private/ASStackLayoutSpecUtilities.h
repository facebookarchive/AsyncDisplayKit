/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStackLayoutSpec.h"

inline CGFloat stackDimension(const ASStackLayoutDirection direction, const CGSize size)
{
  return (direction == ASStackLayoutDirectionVertical) ? size.height : size.width;
}

inline CGFloat crossDimension(const ASStackLayoutDirection direction, const CGSize size)
{
  return (direction == ASStackLayoutDirectionVertical) ? size.width : size.height;
}

inline BOOL compareCrossDimension(const ASStackLayoutDirection direction, const CGSize a, const CGSize b)
{
  return crossDimension(direction, a) < crossDimension(direction, b);
}

inline CGPoint directionPoint(const ASStackLayoutDirection direction, const CGFloat stack, const CGFloat cross)
{
  return (direction == ASStackLayoutDirectionVertical) ? CGPointMake(cross, stack) : CGPointMake(stack, cross);
}

inline CGSize directionSize(const ASStackLayoutDirection direction, const CGFloat stack, const CGFloat cross)
{
  return (direction == ASStackLayoutDirectionVertical) ? CGSizeMake(cross, stack) : CGSizeMake(stack, cross);
}

inline ASSizeRange directionSizeRange(const ASStackLayoutDirection direction,
                                      const CGFloat stackMin,
                                      const CGFloat stackMax,
                                      const CGFloat crossMin,
                                      const CGFloat crossMax)
{
  return {directionSize(direction, stackMin, crossMin), directionSize(direction, stackMax, crossMax)};
}

inline ASStackLayoutAlignItems alignment(ASStackLayoutAlignSelf childAlignment, ASStackLayoutAlignItems stackAlignment)
{
  switch (childAlignment) {
    case ASStackLayoutAlignSelfCenter:
      return ASStackLayoutAlignItemsCenter;
    case ASStackLayoutAlignSelfEnd:
      return ASStackLayoutAlignItemsEnd;
    case ASStackLayoutAlignSelfStart:
      return ASStackLayoutAlignItemsStart;
    case ASStackLayoutAlignSelfStretch:
      return ASStackLayoutAlignItemsStretch;
    case ASStackLayoutAlignSelfAuto:
    default:
      return stackAlignment;
  }
}

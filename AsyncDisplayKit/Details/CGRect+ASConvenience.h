//
//  CGRect+ASConvenience.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "ASBaseDefines.h"
#import "ASLayoutController.h"
#include "tgmath.h"

#ifndef CGFLOAT_EPSILON
  #if CGFLOAT_IS_DOUBLE
    #define CGFLOAT_EPSILON DBL_EPSILON
  #else
    #define CGFLOAT_EPSILON FLT_EPSILON
  #endif
#endif

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

ASDISPLAYNODE_INLINE CGFloat ASCGFloatFromString(NSString *string)
{
#if CGFLOAT_IS_DOUBLE
  return string.doubleValue;
#else
  return string.floatValue;
#endif
}

ASDISPLAYNODE_INLINE CGFloat ASCGFloatFromNumber(NSNumber *number)
{
#if CGFLOAT_IS_DOUBLE
  return number.doubleValue;
#else
  return number.floatValue;
#endif
}

ASDISPLAYNODE_INLINE BOOL CGSizeEqualToSizeWithIn(CGSize size1, CGSize size2, CGFloat delta)
{
  return fabs(size1.width - size2.width) < delta && fabs(size1.height - size2.height) < delta;
};

struct ASDirectionalScreenfulBuffer {
  CGFloat positiveDirection; // Positive relative to iOS Core Animation layer coordinate space.
  CGFloat negativeDirection;
};
typedef struct ASDirectionalScreenfulBuffer ASDirectionalScreenfulBuffer;

ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferHorizontal(ASScrollDirection scrollDirection,
                                                                    ASRangeTuningParameters rangeTuningParameters);

ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferVertical(ASScrollDirection scrollDirection,
                                                                  ASRangeTuningParameters rangeTuningParameters);

CGRect CGRectExpandToRangeWithScrollableDirections(CGRect rect,
                                                   ASRangeTuningParameters tuningParameters,
                                                   ASScrollDirection scrollableDirections,
                                                   ASScrollDirection scrollDirection);

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END

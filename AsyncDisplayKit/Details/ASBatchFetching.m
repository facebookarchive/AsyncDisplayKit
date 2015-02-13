/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASBatchFetching.h"

BOOL ASDisplayShouldFetchBatchForContext(ASBatchContext *context,
                                    ASScrollDirection scrollDirection,
                                    CGRect bounds,
                                    CGSize contentSize,
                                    CGPoint targetOffset,
                                    CGFloat leadingScreens) {
  // do not allow fetching if a batch is already in-flight and hasn't been completed or cancelled
  if ([context isFetching]) {
    return NO;
  }

  // no fetching for null states
  if (leadingScreens <= 0.0 ||
      CGPointEqualToPoint(targetOffset, CGPointZero) ||
      CGSizeEqualToSize(contentSize, CGSizeZero) ||
      CGRectEqualToRect(bounds, CGRectZero)) {
    return NO;
  }

  // only Up and Left scrolls are currently supported (tail loading)
  if (scrollDirection != ASScrollDirectionUp && scrollDirection != ASScrollDirectionLeft) {
    return NO;
  }

  CGFloat viewLength, offset, contentLength;

  if (scrollDirection == ASScrollDirectionUp) {
    viewLength = bounds.size.height;
    offset = targetOffset.y;
    contentLength = contentSize.height;
  } else { // horizontal
    viewLength = bounds.size.width;
    offset = targetOffset.x;
    contentLength = contentSize.width;
  }

  CGFloat triggerDistance = viewLength * leadingScreens;
  CGFloat remainingDistance = contentLength - viewLength - offset;

  return remainingDistance <= triggerDistance;
}

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
                                    BOOL isScrollingTowardsTail,
                                    CGRect bounds,
                                    CGSize contentSize,
                                    CGPoint targetOffset,
                                    CGFloat leadingScreens,
                                    CGFloat trailingScreens) {
  // do not allow fetching if a batch is already in-flight and hasn't been completed or cancelled
  if ([context isFetching]) {
    return NO;
  }

  // no fetching for null states
  if (leadingScreens <= 0.0 ||
      trailingScreens <= 0.0 ||
      CGRectEqualToRect(bounds, CGRectZero)) {
    return NO;
  }

  CGFloat viewLength, offset, contentLength;

  if (ASScrollDirectionContainsVerticalDirection(scrollDirection)) {
    viewLength = bounds.size.height;
    offset = targetOffset.y;
    contentLength = contentSize.height;
  } else {
    viewLength = bounds.size.width;
    offset = targetOffset.x;
    contentLength = contentSize.width;
  }

  // target offset will always be 0 if the content size is smaller than the viewport
  BOOL hasSmallContent = offset == 0.0 && contentLength < viewLength;
  CGFloat triggerDistance, remainingDistance;
  /*  
   *  ______
   * |      |
   *  ______  <-- if ASScrollDirectionDown and trailingScreens == 1, trigger when this is on screen
   * |      |
   *  ______  <-- if ASScrollDirectionUp and leadingScreens == 1, trigger when this is on screen
   * |      |
   *  ______
   *
   */
  if (isScrollingTowardsTail) {
    triggerDistance = viewLength * leadingScreens;
    remainingDistance = contentLength - viewLength - offset;
  } else {
    triggerDistance = viewLength * trailingScreens;
    remainingDistance = offset - viewLength;
  }
  return hasSmallContent || (remainingDistance <= triggerDistance);
}

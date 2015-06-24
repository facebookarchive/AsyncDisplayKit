/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "CGRect+ASConvenience.h"

CGRect asdk_CGRectExpandHorizontally(CGRect rect, CGFloat negativeMultiplier, CGFloat positiveMultiplier) {
  CGFloat negativeDirectionWidth = negativeMultiplier * rect.size.width;
  CGFloat positiveDirectionWidth = positiveMultiplier * rect.size.width;
  CGFloat width = negativeDirectionWidth + rect.size.width + positiveDirectionWidth;
  CGFloat originX = rect.origin.x - negativeDirectionWidth;
  return CGRectMake(originX,
                    rect.origin.y,
                    width,
                    rect.size.height);
}

CGRect asdk_CGRectExpandVertically(CGRect rect, CGFloat negativeMultiplier, CGFloat positiveMultiplier) {
  CGFloat negativeDirectionHeight = negativeMultiplier * rect.size.height;
  CGFloat positiveDirectionHeight = positiveMultiplier * rect.size.height;
  CGFloat height = negativeDirectionHeight + rect.size.height + positiveDirectionHeight;
  CGFloat originY = rect.origin.y - negativeDirectionHeight;
  return CGRectMake(rect.origin.x,
                    originY,
                    rect.size.width,
                    height);
}

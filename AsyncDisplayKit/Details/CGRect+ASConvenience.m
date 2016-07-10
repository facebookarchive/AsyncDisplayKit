//
//  CGRect+ASConvenience.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "CGRect+ASConvenience.h"

ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferHorizontal(ASScrollDirection scrollDirection,
                                                                    ASRangeTuningParameters rangeTuningParameters)
{
  ASDirectionalScreenfulBuffer horizontalBuffer = {0, 0};
  BOOL movingRight = ASScrollDirectionContainsRight(scrollDirection);
  
  horizontalBuffer.positiveDirection = movingRight ? rangeTuningParameters.leadingBufferScreenfuls
                                                   : rangeTuningParameters.trailingBufferScreenfuls;
  horizontalBuffer.negativeDirection = movingRight ? rangeTuningParameters.trailingBufferScreenfuls
                                                   : rangeTuningParameters.leadingBufferScreenfuls;
  return horizontalBuffer;
}

ASDirectionalScreenfulBuffer ASDirectionalScreenfulBufferVertical(ASScrollDirection scrollDirection,
                                                                  ASRangeTuningParameters rangeTuningParameters)
{
  ASDirectionalScreenfulBuffer verticalBuffer = {0, 0};
  BOOL movingDown = ASScrollDirectionContainsDown(scrollDirection);
  
  verticalBuffer.positiveDirection = movingDown ? rangeTuningParameters.leadingBufferScreenfuls
                                                : rangeTuningParameters.trailingBufferScreenfuls;
  verticalBuffer.negativeDirection = movingDown ? rangeTuningParameters.trailingBufferScreenfuls
                                                : rangeTuningParameters.leadingBufferScreenfuls;
  return verticalBuffer;
}

CGRect CGRectExpandHorizontally(CGRect rect, ASDirectionalScreenfulBuffer buffer)
{
  CGFloat negativeDirectionWidth = buffer.negativeDirection * rect.size.width;
  CGFloat positiveDirectionWidth = buffer.positiveDirection * rect.size.width;
  rect.size.width = negativeDirectionWidth + rect.size.width + positiveDirectionWidth;
  rect.origin.x -= negativeDirectionWidth;
  return rect;
}

CGRect CGRectExpandVertically(CGRect rect, ASDirectionalScreenfulBuffer buffer)
{
  CGFloat negativeDirectionHeight = buffer.negativeDirection * rect.size.height;
  CGFloat positiveDirectionHeight = buffer.positiveDirection * rect.size.height;
  rect.size.height = negativeDirectionHeight + rect.size.height + positiveDirectionHeight;
  rect.origin.y -= negativeDirectionHeight;
  return rect;
}

CGRect CGRectExpandToRangeWithScrollableDirections(CGRect rect, ASRangeTuningParameters tuningParameters,
                                                   ASScrollDirection scrollableDirections, ASScrollDirection scrollDirection)
{
  // Can scroll horizontally - expand the range appropriately
  if (ASScrollDirectionContainsHorizontalDirection(scrollableDirections)) {
    ASDirectionalScreenfulBuffer horizontalBuffer = ASDirectionalScreenfulBufferHorizontal(scrollDirection, tuningParameters);
    rect = CGRectExpandHorizontally(rect, horizontalBuffer);
  }

  // Can scroll vertically - expand the range appropriately
  if (ASScrollDirectionContainsVerticalDirection(scrollableDirections)) {
    ASDirectionalScreenfulBuffer verticalBuffer = ASDirectionalScreenfulBufferVertical(scrollDirection, tuningParameters);
    rect = CGRectExpandVertically(rect, verticalBuffer);
  }
  
  return rect;
}


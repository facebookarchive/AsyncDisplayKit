/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#include <CoreGraphics/CGBase.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ASBaseDefines.h"

ASDISPLAYNODE_EXTERN_C_BEGIN

BOOL ASSubclassOverridesSelector(Class superclass, Class subclass, SEL selector);
BOOL ASSubclassOverridesClassSelector(Class superclass, Class subclass, SEL selector);
void ASPerformBlockOnMainThread(void (^block)());
void ASPerformBlockOnBackgroundThread(void (^block)()); // DISPATCH_QUEUE_PRIORITY_DEFAULT 

CGFloat ASScreenScale();

CGFloat ASFloorPixelValue(CGFloat f);

CGFloat ASCeilPixelValue(CGFloat f);

CGFloat ASRoundPixelValue(CGFloat f);

BOOL ASRunningOnOS7();

ASDISPLAYNODE_EXTERN_C_END

/**
 @summary Conditionally performs UIView geometry changes in the given block without animation and call completion block afterwards.
 
 Used primarily to circumvent UITableView forcing insertion animations when explicitly told not to via
 `UITableViewRowAnimationNone`. More info: https://github.com/facebook/AsyncDisplayKit/pull/445
 
 @param withoutAnimation Set to `YES` to perform given block without animation
 @param block Perform UIView geometry changes within the passed block
 @param completion Call completion block if UIView geometry changes within the passed block did complete
 */
ASDISPLAYNODE_INLINE void ASPerformBlockWithoutAnimationCompletion(BOOL withoutAnimation, void (^block)(), void (^completion)()) {
  [CATransaction begin];
  [CATransaction setDisableActions:withoutAnimation];
  if (completion != nil) {
    [CATransaction setCompletionBlock:completion];
  }
  block();
  [CATransaction commit];
}

/**
 @summary Conditionally performs UIView geometry changes in the given block without animation.
 
 Used primarily to circumvent UITableView forcing insertion animations when explicitly told not to via
 `UITableViewRowAnimationNone`. More info: https://github.com/facebook/AsyncDisplayKit/pull/445
 
 @param withoutAnimation Set to `YES` to perform given block without animation
 @param block Perform UIView geometry changes within the passed block
 */
ASDISPLAYNODE_INLINE void ASPerformBlockWithoutAnimation(BOOL withoutAnimation, void (^block)()) {
  ASPerformBlockWithoutAnimationCompletion(withoutAnimation, block, nil);
}

ASDISPLAYNODE_INLINE void ASBoundsAndPositionForFrame(CGRect rect, CGPoint origin, CGPoint anchorPoint, CGRect *bounds, CGPoint *position)
{
  *bounds   = (CGRect){ origin, rect.size };
  *position = CGPointMake(rect.origin.x + rect.size.width * anchorPoint.x,
                          rect.origin.y + rect.size.height * anchorPoint.y);
}

@interface NSIndexPath (ASInverseComparison)
- (NSComparisonResult)asdk_inverseCompare:(NSIndexPath *)otherIndexPath;
@end

//
//  ASRelativeLayoutSpec.mm
//  AsyncDisplayKit
//
//  Created by Samuel Stow on 12/31/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASRelativeLayoutSpec.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASThread.h"

#pragma mark - Helper

ASDISPLAYNODE_INLINE CGFloat ASRelativeLayoutSpecProportionOfAxisForAxisPosition(ASRelativeLayoutSpecPosition position)
{
  if ((position & ASRelativeLayoutSpecPositionCenter) != 0) {
    return 0.5f;
  } else if ((position & ASRelativeLayoutSpecPositionEnd) != 0) {
    return 1.0f;
  } else {
    return 0.0f;
  }
}

#pragma mark - ASRelativeLayoutSpecStyleDeclaration

@implementation ASRelativeLayoutSpecStyleDeclaration

@end


#pragma mark - ASRelativeLayoutSpec

@implementation ASRelativeLayoutSpec {
  ASDN::RecursiveMutex __instanceLock__;
  ASRelativeLayoutSpecStyleDeclaration *_style;
}

#pragma mark - Class

+ (instancetype)relativePositionLayoutSpecWithHorizontalPosition:(ASRelativeLayoutSpecPosition)horizontalPosition verticalPosition:(ASRelativeLayoutSpecPosition)verticalPosition sizingOption:(ASRelativeLayoutSpecSizingOption)sizingOption child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithHorizontalPosition:horizontalPosition verticalPosition:verticalPosition sizingOption:sizingOption child:child];
}

#pragma mark - Lifecycle

- (instancetype)initWithHorizontalPosition:(ASRelativeLayoutSpecPosition)horizontalPosition verticalPosition:(ASRelativeLayoutSpecPosition)verticalPosition sizingOption:(ASRelativeLayoutSpecSizingOption)sizingOption child:(id<ASLayoutable>)child
{
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  
  if (!(self = [super init])) {
    return nil;
  }
  
  _style = [[ASRelativeLayoutSpecStyleDeclaration alloc] init];
  _style.horizontalPosition = horizontalPosition;
  _style.verticalPosition = verticalPosition;
  _style.sizingOption = sizingOption;
  
  self.child = child;
  
  return self;
}

#pragma mark - Getter / Setter

- (ASRelativeLayoutSpecStyleDeclaration *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}

#pragma mark - ASLayoutSpec

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  // If we have a finite size in any direction, pass this so that the child can
  // resolve percentages against it. Otherwise pass ASLayoutableParentDimensionUndefined
  // as the size will depend on the content
  // TODO: layout: isValidForLayout() call should not be necessary if INFINITY is used
  CGSize size = {
    isinf(constrainedSize.max.width) || !ASPointsAreValidForLayout(constrainedSize.max.width) ? ASLayoutableParentDimensionUndefined : constrainedSize.max.width,
    isinf(constrainedSize.max.height) || !ASPointsAreValidForLayout(constrainedSize.max.height) ? ASLayoutableParentDimensionUndefined : constrainedSize.max.height
  };
  
  BOOL reduceWidth = (self.style.horizontalPosition & ASRelativeLayoutSpecPositionCenter) != 0 ||
  (self.style.horizontalPosition & ASRelativeLayoutSpecPositionEnd) != 0;
  
  BOOL reduceHeight = (self.style.verticalPosition & ASRelativeLayoutSpecPositionCenter) != 0 ||
  (self.style.verticalPosition & ASRelativeLayoutSpecPositionEnd) != 0;
  
  // Layout the child
  const CGSize minChildSize = {
    reduceWidth ? 0 : constrainedSize.min.width,
    reduceHeight ? 0 : constrainedSize.min.height,
  };
  
  ASLayout *sublayout = [self.child layoutThatFits:ASSizeRangeMake(minChildSize, constrainedSize.max) parentSize:size];
  
  // If we have an undetermined height or width, use the child size to define the layout
  // size
  size = ASSizeRangeClamp(constrainedSize, {
    isfinite(size.width) == NO ? sublayout.size.width : size.width,
    isfinite(size.height) == NO ? sublayout.size.height : size.height
  });
  
  // If minimum size options are set, attempt to shrink the size to the size of the child
  size = ASSizeRangeClamp(constrainedSize, {
    MIN(size.width, (self.style.sizingOption & ASRelativeLayoutSpecSizingOptionMinimumWidth) != 0 ? sublayout.size.width : size.width),
    MIN(size.height, (self.style.sizingOption & ASRelativeLayoutSpecSizingOptionMinimumHeight) != 0 ? sublayout.size.height : size.height)
  });
  
  // Compute the position for the child on each axis according to layout parameters
  CGFloat xPosition = ASRelativeLayoutSpecProportionOfAxisForAxisPosition(self.style.horizontalPosition);
  CGFloat yPosition = ASRelativeLayoutSpecProportionOfAxisForAxisPosition(self.style.verticalPosition);
  
  sublayout.position = {
    ASRoundPixelValue((size.width - sublayout.size.width) * xPosition),
    ASRoundPixelValue((size.height - sublayout.size.height) * yPosition)
  };
  
  return [ASLayout layoutWithLayoutable:self size:size sublayouts:@[sublayout]];
}

@end

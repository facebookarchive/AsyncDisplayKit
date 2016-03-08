/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASCenterLayoutSpec.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

@implementation ASCenterLayoutSpec
{
  ASCenterLayoutSpecCenteringOptions _centeringOptions;
  ASCenterLayoutSpecSizingOptions _sizingOptions;
  ASRelativeLayoutSpec *_internalLayoutSpec;
}

- (instancetype)initWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                           sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                   child:(id<ASLayoutable>)child;
{
  if (!(self = [super init])) {
    return nil;
  }
  _centeringOptions = centeringOptions;
  _sizingOptions = sizingOptions;
  
  ASRelativeLayoutSpecPosition verticalPosition = [self verticalPositionFromCenteringOptions:centeringOptions];
  ASRelativeLayoutSpecPosition horizontalPosition = [self horizontalPositionFromCenteringOptions:centeringOptions];
  
  _internalLayoutSpec = [ASRelativeLayoutSpec relativePositionLayoutSpecWithHorizontalPosition:horizontalPosition verticalPosition:verticalPosition sizingOption:sizingOptions child:child];
  
  return self;
}

+ (instancetype)centerLayoutSpecWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                                       sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                               child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithCenteringOptions:centeringOptions sizingOptions:sizingOptions child:child];
}

- (void)setCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _centeringOptions = centeringOptions;
  
  [_internalLayoutSpec setHorizontalPosition:[self horizontalPositionFromCenteringOptions:centeringOptions]];
  [_internalLayoutSpec setVerticalPosition:[self verticalPositionFromCenteringOptions:centeringOptions]];
}

- (void)setSizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _sizingOptions = sizingOptions;

  [_internalLayoutSpec setSizingOption:sizingOptions];
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [_internalLayoutSpec measureWithSizeRange:constrainedSize];
}

- (void)setChildren:(NSArray *)children
{
  [_internalLayoutSpec setChildren:children];
}

- (NSArray *)children
{
  return [_internalLayoutSpec children];
}

- (ASRelativeLayoutSpecPosition)horizontalPositionFromCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions {
  BOOL centerX =  (centeringOptions & ASCenterLayoutSpecCenteringX) != 0;
  if (centerX) {
    return ASRelativeLayoutSpecPositionCenter;
  } else {
    return ASRelativeLayoutSpecPositionStart;
  }
}

- (ASRelativeLayoutSpecPosition)verticalPositionFromCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions {
  BOOL centerY =  (centeringOptions & ASCenterLayoutSpecCenteringY) != 0;
  if (centerY) {
    return ASRelativeLayoutSpecPositionCenter;
  } else {
    return ASRelativeLayoutSpecPositionStart;
  }
}



@end

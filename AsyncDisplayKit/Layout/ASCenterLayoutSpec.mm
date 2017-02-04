//
//  ASCenterLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCenterLayoutSpec.h>

#import <AsyncDisplayKit/ASLayout.h>

@implementation ASCenterLayoutSpec
{
  ASCenterLayoutSpecCenteringOptions _centeringOptions;
  ASCenterLayoutSpecSizingOptions _sizingOptions;
}

- (instancetype)initWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                           sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                   child:(id<ASLayoutElement>)child;
{
  ASRelativeLayoutSpecPosition verticalPosition = [self verticalPositionFromCenteringOptions:centeringOptions];
  ASRelativeLayoutSpecPosition horizontalPosition = [self horizontalPositionFromCenteringOptions:centeringOptions];
  
  if (!(self = [super initWithHorizontalPosition:horizontalPosition verticalPosition:verticalPosition sizingOption:sizingOptions child:child])) {
    return nil;
  }
  _centeringOptions = centeringOptions;
  _sizingOptions = sizingOptions;
  return self;
}

+ (instancetype)centerLayoutSpecWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                                       sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                               child:(id<ASLayoutElement>)child
{
  return [[self alloc] initWithCenteringOptions:centeringOptions sizingOptions:sizingOptions child:child];
}

- (void)setCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _centeringOptions = centeringOptions;
  
  [self setHorizontalPosition:[self horizontalPositionFromCenteringOptions:centeringOptions]];
  [self setVerticalPosition:[self verticalPositionFromCenteringOptions:centeringOptions]];
}

- (void)setSizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _sizingOptions = sizingOptions;
  [self setSizingOption:sizingOptions];
}

- (ASRelativeLayoutSpecPosition)horizontalPositionFromCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
{
  if ((centeringOptions & ASCenterLayoutSpecCenteringX) != 0) {
    return ASRelativeLayoutSpecPositionCenter;
  } else {
    return ASRelativeLayoutSpecPositionNone;
  }
}

- (ASRelativeLayoutSpecPosition)verticalPositionFromCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
{
  if ((centeringOptions & ASCenterLayoutSpecCenteringY) != 0) {
    return ASRelativeLayoutSpecPositionCenter;
  } else {
    return ASRelativeLayoutSpecPositionNone;
  }
}

@end

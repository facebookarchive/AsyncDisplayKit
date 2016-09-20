//
//  ASCenterLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASCenterLayoutSpec.h"

#import "ASLayout.h"
#import "ASThread.h"


#pragma mark - Helper

static ASRelativeLayoutSpecPosition ASCenterLayoutSpecVerticalPositionFromCenteringOptions(ASCenterLayoutSpecCenteringOptions centeringOptions)
{
  BOOL centerY = (centeringOptions & ASCenterLayoutSpecCenteringY) != 0;
  if (centerY) {
    return ASRelativeLayoutSpecPositionCenter;
  } else {
    return ASRelativeLayoutSpecPositionStart;
  }
}

static ASRelativeLayoutSpecPosition ASCenterLayoutSpecHorizontalPositionFromCenteringOptions(ASCenterLayoutSpecCenteringOptions centeringOptions)
{
  BOOL centerX =  (centeringOptions & ASCenterLayoutSpecCenteringX) != 0;
  if (centerX) {
    return ASRelativeLayoutSpecPositionCenter;
  } else {
    return ASRelativeLayoutSpecPositionStart;
  }
}


#pragma mark - ASCenterLayoutSpecStyleDeclaration

@implementation ASCenterLayoutSpecStyleDeclaration

- (void)setCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
{
  _centeringOptions = centeringOptions;
  
  self.verticalPosition = ASCenterLayoutSpecVerticalPositionFromCenteringOptions(centeringOptions);
  self.horizontalPosition = ASCenterLayoutSpecHorizontalPositionFromCenteringOptions(centeringOptions);
}

- (void)setSizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
{
  _sizingOptions = sizingOptions;
  [super setSizingOption:sizingOptions];
}

@end


#pragma mark - ASCenterLayoutSpec

@implementation ASCenterLayoutSpec {
  ASDN::RecursiveMutex __instanceLock__;
  ASCenterLayoutSpecStyleDeclaration *_style;
}

#pragma mark - Class

+ (instancetype)centerLayoutSpecWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                                       sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                               child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithCenteringOptions:centeringOptions sizingOptions:sizingOptions child:child];
}

#pragma mark - Lifecycle

- (instancetype)initWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                           sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                   child:(id<ASLayoutable>)child;
{
  ASRelativeLayoutSpecPosition verticalPosition = ASCenterLayoutSpecVerticalPositionFromCenteringOptions(centeringOptions);
  ASRelativeLayoutSpecPosition horizontalPosition = ASCenterLayoutSpecHorizontalPositionFromCenteringOptions(centeringOptions);
  
  self = [super initWithHorizontalPosition:horizontalPosition verticalPosition:verticalPosition sizingOption:sizingOptions child:child];
  if (self == nil) {
    return nil;
  }
  
  _style.centeringOptions = centeringOptions;
  _style.sizingOptions = sizingOptions;
  
  return self;
}

#pragma mark - Style

- (void)loadStyle
{
  _style = [[ASCenterLayoutSpecStyleDeclaration alloc] init];
}

- (ASRelativeLayoutSpecStyleDeclaration *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}

@end

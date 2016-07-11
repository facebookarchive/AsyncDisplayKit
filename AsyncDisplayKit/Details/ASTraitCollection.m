//
//  ASTraitCollection.m
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 5/4/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTraitCollection.h"
#import <AsyncDisplayKit/ASAvailability.h>

@implementation ASTraitCollection

- (instancetype)initWithDisplayScale:(CGFloat)displayScale
                  userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                 horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                   verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                 containerSize:(CGSize)windowSize
{
    self = [super init];
    if (self) {
      _displayScale = displayScale;
      _userInterfaceIdiom = userInterfaceIdiom;
      _horizontalSizeClass = horizontalSizeClass;
      _verticalSizeClass = verticalSizeClass;
      _forceTouchCapability = forceTouchCapability;
      _containerSize = windowSize;
    }
    return self;
}

+ (ASTraitCollection *)traitCollectionWithDisplayScale:(CGFloat)displayScale
                                    userInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
                                   horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
                                     verticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
                                  forceTouchCapability:(UIForceTouchCapability)forceTouchCapability
                                   containerSize:(CGSize)windowSize
{
  return [[[self class] alloc] initWithDisplayScale:displayScale
                                 userInterfaceIdiom:userInterfaceIdiom
                                horizontalSizeClass:horizontalSizeClass
                                  verticalSizeClass:verticalSizeClass
                               forceTouchCapability:forceTouchCapability
                             containerSize:windowSize];
}

+ (ASTraitCollection *)traitCollectionWithASEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traits
{
    return [[[self class] alloc] initWithDisplayScale:traits.displayScale
                                   userInterfaceIdiom:traits.userInterfaceIdiom
                                  horizontalSizeClass:traits.horizontalSizeClass
                                    verticalSizeClass:traits.verticalSizeClass
                                 forceTouchCapability:traits.forceTouchCapability
                                        containerSize:traits.containerSize];

}

+ (ASTraitCollection *)traitCollectionWithUITraitCollection:(UITraitCollection *)traitCollection
                                        containerSize:(CGSize)windowSize
{
  ASTraitCollection *asyncTraitCollection = nil;
  if (AS_AT_LEAST_IOS9) {
    asyncTraitCollection = [[[self class] alloc] initWithDisplayScale:traitCollection.displayScale
                                                   userInterfaceIdiom:traitCollection.userInterfaceIdiom
                                                  horizontalSizeClass:traitCollection.horizontalSizeClass
                                                    verticalSizeClass:traitCollection.verticalSizeClass
                                                 forceTouchCapability:traitCollection.forceTouchCapability
                                                  containerSize:windowSize];
  }
  else if (AS_AT_LEAST_IOS8) {
    asyncTraitCollection = [[[self class] alloc] initWithDisplayScale:traitCollection.displayScale
                                                   userInterfaceIdiom:traitCollection.userInterfaceIdiom
                                                  horizontalSizeClass:traitCollection.horizontalSizeClass
                                                    verticalSizeClass:traitCollection.verticalSizeClass
                                                 forceTouchCapability:0
                                                  containerSize:windowSize];
  } else {
    asyncTraitCollection = [[[self class] alloc] init];
  }
  
  return asyncTraitCollection;
}

- (ASEnvironmentTraitCollection)environmentTraitCollection
{
  return (ASEnvironmentTraitCollection) {
    .displayScale = self.displayScale,
    .horizontalSizeClass = self.horizontalSizeClass,
    .userInterfaceIdiom = self.userInterfaceIdiom,
    .verticalSizeClass = self.verticalSizeClass,
    .forceTouchCapability = self.forceTouchCapability,
    .containerSize = self.containerSize,
  };
}

- (BOOL)isEqualToTraitCollection:(ASTraitCollection *)traitCollection
{
  return self.displayScale == traitCollection.displayScale &&
  self.horizontalSizeClass == traitCollection.horizontalSizeClass &&
  self.verticalSizeClass == traitCollection.verticalSizeClass &&
  self.userInterfaceIdiom == traitCollection.userInterfaceIdiom &&
  CGSizeEqualToSize(self.containerSize, traitCollection.containerSize) &&
  self.forceTouchCapability == traitCollection.forceTouchCapability;
}

@end

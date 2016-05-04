//
//  ASDisplayTraits.m
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 5/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASDisplayTraits.h"
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASAvailability.h>

@implementation ASDisplayTraits

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isMutable = YES;
    }
    return self;
}

- (void)setDisplayScale:(CGFloat)displayScale
{
  ASDisplayNodeAssert(self.isMutable, @"ASDisplayTraits is no longer mutable");
  _displayScale = displayScale;
}

- (void)setHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
{
  ASDisplayNodeAssert(self.isMutable, @"ASDisplayTraits is no longer mutable");
  _horizontalSizeClass = horizontalSizeClass;
}

- (void)setUserInterfaceIdiom:(UIUserInterfaceIdiom)userInterfaceIdiom
{
  ASDisplayNodeAssert(self.isMutable, @"ASDisplayTraits is no longer mutable");
  _userInterfaceIdiom = userInterfaceIdiom;
}

- (void)setVerticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass
{
  ASDisplayNodeAssert(self.isMutable, @"ASDisplayTraits is no longer mutable");
  _verticalSizeClass = verticalSizeClass;
}

- (void)setForceTouchCapability:(UIForceTouchCapability)forceTouchCapability
{
  ASDisplayNodeAssert(self.isMutable, @"ASDisplayTraits is no longer mutable");
  _forceTouchCapability = forceTouchCapability;
}

+ (ASDisplayTraits *)displayTraitsWithASEnvironmentDisplayTraits:(ASEnvironmentDisplayTraits)traits
{
  ASDisplayTraits *displayTraits = [[ASDisplayTraits alloc] init];
  displayTraits.displayScale = traits.displayScale;
  displayTraits.horizontalSizeClass = traits.horizontalSizeClass;
  displayTraits.verticalSizeClass = traits.verticalSizeClass;
  displayTraits.userInterfaceIdiom = traits.userInterfaceIdiom;
  displayTraits.forceTouchCapability = traits.forceTouchCapability;
  return displayTraits;
}

+ (ASDisplayTraits *)displayTraitsWithUITraitCollection:(UITraitCollection *)traitCollection
{
  ASDisplayTraits *displayTraits = [[ASDisplayTraits alloc] init];
  if (AS_AT_LEAST_IOS8) {
    displayTraits.displayScale = traitCollection.displayScale;
    displayTraits.horizontalSizeClass = traitCollection.horizontalSizeClass;
    displayTraits.verticalSizeClass = traitCollection.verticalSizeClass;
    displayTraits.userInterfaceIdiom = traitCollection.userInterfaceIdiom;
    if (AS_AT_LEAST_IOS9) {
      displayTraits.forceTouchCapability = traitCollection.forceTouchCapability;
    }
  }
  return displayTraits;
}

- (ASEnvironmentDisplayTraits)environmentDisplayTraits
{
  return (ASEnvironmentDisplayTraits) {
    .displayScale = self.displayScale,
    .horizontalSizeClass = self.horizontalSizeClass,
    .userInterfaceIdiom = self.userInterfaceIdiom,
    .verticalSizeClass = self.verticalSizeClass,
    .forceTouchCapability = self.forceTouchCapability,
  };
}

@end

//
//  ASDisplayTraits.m
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 5/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASTraitCollection.h"
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASAvailability.h>

@implementation ASTraitCollection

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

+ (ASTraitCollection *)displayTraitsWithASEnvironmentTraitCollection:(ASEnvironmentTraitCollection)traits
{
  ASTraitCollection *traitCollection = [[ASTraitCollection alloc] init];
  traitCollection.displayScale = traits.displayScale;
  traitCollection.horizontalSizeClass = traits.horizontalSizeClass;
  traitCollection.verticalSizeClass = traits.verticalSizeClass;
  traitCollection.userInterfaceIdiom = traits.userInterfaceIdiom;
  traitCollection.forceTouchCapability = traits.forceTouchCapability;
  return traitCollection;
}

+ (ASTraitCollection *)displayTraitsWithUITraitCollection:(UITraitCollection *)traitCollection
{
  ASTraitCollection *asyncTraitCollection = [[ASTraitCollection alloc] init];
  if (AS_AT_LEAST_IOS8) {
    asyncTraitCollection.displayScale = traitCollection.displayScale;
    asyncTraitCollection.horizontalSizeClass = traitCollection.horizontalSizeClass;
    asyncTraitCollection.verticalSizeClass = traitCollection.verticalSizeClass;
    asyncTraitCollection.userInterfaceIdiom = traitCollection.userInterfaceIdiom;
    if (AS_AT_LEAST_IOS9) {
      asyncTraitCollection.forceTouchCapability = traitCollection.forceTouchCapability;
    }
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
  };
}

@end

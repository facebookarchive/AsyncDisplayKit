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
#import "ASAvailability.h"
#import "ASObjectDescriptionHelpers.h"
#import "ASLayoutElement.h"

#pragma mark - ASLayoutElementTraitCollection

extern void ASLayoutElementTraitCollectionPropagateDown(id<ASLayoutElement> root, ASLayoutElementTraitCollection traitCollection) {
  ASLayoutElementPerformBlockOnEveryElement(root, ^(id<ASLayoutElement>  _Nonnull element) {
    element.layoutElementTraitCollection = traitCollection;
  });
}

ASLayoutElementTraitCollection ASLayoutElementTraitCollectionMakeDefault()
{
  return (ASLayoutElementTraitCollection) {
    // Default values can be defined in here
    .userInterfaceIdiom = UIUserInterfaceIdiomUnspecified,
    .containerSize = CGSizeZero,
  };
}

ASLayoutElementTraitCollection ASLayoutElementTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection)
{
  ASLayoutElementTraitCollection environmentTraitCollection = ASLayoutElementTraitCollectionMakeDefault();
  if (AS_AT_LEAST_IOS8) {
    environmentTraitCollection.displayScale = traitCollection.displayScale;
    environmentTraitCollection.horizontalSizeClass = traitCollection.horizontalSizeClass;
    environmentTraitCollection.verticalSizeClass = traitCollection.verticalSizeClass;
    environmentTraitCollection.userInterfaceIdiom = traitCollection.userInterfaceIdiom;
    if (AS_AT_LEAST_IOS9) {
      environmentTraitCollection.forceTouchCapability = traitCollection.forceTouchCapability;
    }
  }
  return environmentTraitCollection;
}

BOOL ASLayoutElementTraitCollectionIsEqualToASLayoutElementTraitCollection(ASLayoutElementTraitCollection lhs, ASLayoutElementTraitCollection rhs)
{
  return
    lhs.verticalSizeClass == rhs.verticalSizeClass &&
    lhs.horizontalSizeClass == rhs.horizontalSizeClass &&
    lhs.displayScale == rhs.displayScale &&
    lhs.userInterfaceIdiom == rhs.userInterfaceIdiom &&
    lhs.forceTouchCapability == rhs.forceTouchCapability &&
    CGSizeEqualToSize(lhs.containerSize, rhs.containerSize);
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIUserInterfaceIdiom(UIUserInterfaceIdiom idiom) {
  switch (idiom) {
    case UIUserInterfaceIdiomTV:
      return @"TV";
    case UIUserInterfaceIdiomPad:
      return @"Pad";
    case UIUserInterfaceIdiomPhone:
      return @"Phone";
    case UIUserInterfaceIdiomCarPlay:
      return @"CarPlay";
    default:
      return @"Unspecified";
  }
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIForceTouchCapability(UIForceTouchCapability capability) {
  switch (capability) {
    case UIForceTouchCapabilityAvailable:
      return @"Available";
    case UIForceTouchCapabilityUnavailable:
      return @"Unavailable";
    default:
      return @"Unknown";
  }
}

// Named so as not to conflict with a hidden Apple function, in case compiler decides not to inline
ASDISPLAYNODE_INLINE NSString *AS_NSStringFromUIUserInterfaceSizeClass(UIUserInterfaceSizeClass sizeClass) {
  switch (sizeClass) {
    case UIUserInterfaceSizeClassCompact:
      return @"Compact";
    case UIUserInterfaceSizeClassRegular:
      return @"Regular";
    default:
      return @"Unspecified";
  }
}

NSString *NSStringFromASLayoutElementTraitCollection(ASLayoutElementTraitCollection traits)
{
  NSMutableArray<NSDictionary *> *props = [NSMutableArray array];
  [props addObject:@{ @"userInterfaceIdiom": AS_NSStringFromUIUserInterfaceIdiom(traits.userInterfaceIdiom) }];
  [props addObject:@{ @"containerSize": NSStringFromCGSize(traits.containerSize) }];
  [props addObject:@{ @"horizontalSizeClass": AS_NSStringFromUIUserInterfaceSizeClass(traits.horizontalSizeClass) }];
  [props addObject:@{ @"verticalSizeClass": AS_NSStringFromUIUserInterfaceSizeClass(traits.verticalSizeClass) }];
  [props addObject:@{ @"forceTouchCapability": AS_NSStringFromUIForceTouchCapability(traits.forceTouchCapability) }];
  return ASObjectDescriptionMakeWithoutObject(props);
}

#pragma mark - ASTraitCollection

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

+ (ASTraitCollection *)traitCollectionWithASLayoutElementTraitCollection:(ASLayoutElementTraitCollection)traits
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

- (ASLayoutElementTraitCollection)layoutElementTraitCollection
{
  return (ASLayoutElementTraitCollection) {
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

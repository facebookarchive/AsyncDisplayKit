//
//  ASDisplayTraitCollection.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 3/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASDisplayTraitCollection.h"

@interface ASDisplayTraitCollection ()

@property (nonatomic, assign) ASTraits builtinTraits;

@end

@implementation ASDisplayTraitCollection

- (instancetype)initWithTraits:(ASTraits)traits
{
  self = [super init];
  if (self != nil) {
    _builtinTraits = traits;
  }
  return self;
}

- (UITraitCollection *)traitCollection
{
  return [UITraitCollection traitCollectionWithTraitsFromCollections:@[
    [UITraitCollection traitCollectionWithDisplayScale:_builtinTraits.displayScale],
    [UITraitCollection traitCollectionWithUserInterfaceIdiom:_builtinTraits.userInterfaceIdiom],
    [UITraitCollection traitCollectionWithHorizontalSizeClass:_builtinTraits.horizontalSizeClass],
    [UITraitCollection traitCollectionWithVerticalSizeClass:_builtinTraits.verticalSizeClass],
    [UITraitCollection traitCollectionWithForceTouchCapability:_builtinTraits.forceTouchCapability],
  ]];
}

#pragma mark - ASTraitCollection Protocol

- (CGFloat)displayScale
{
  return _builtinTraits.displayScale;
}

- (UIUserInterfaceSizeClass)horizontalSizeClass
{
  return _builtinTraits.horizontalSizeClass;
}

- (UIUserInterfaceSizeClass)verticalSizeClass
{
  return _builtinTraits.verticalSizeClass;
}

- (UIUserInterfaceIdiom)userInterfaceIdiom
{
  return _builtinTraits.userInterfaceIdiom;
}

- (UIForceTouchCapability)forceTouchCapability
{
  return _builtinTraits.forceTouchCapability;
}

- (BOOL)containsTraitsInCollection:(id<ASTraitCollection>)trait
{
  // TODO(levi): Implement
  return NO;
}

@end

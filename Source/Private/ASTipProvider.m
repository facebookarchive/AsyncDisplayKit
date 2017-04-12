//
//  ASTipProvider.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTipProvider.h"

#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASAssert.h>

// Concrete classes
#import <AsyncDisplayKit/ASLayerBackingTipProvider.h>

@implementation ASTipProvider

- (ASTip *)tipForNode:(ASDisplayNode *)node
{
  ASDisplayNodeFailAssert(@"Subclasses must override %@", NSStringFromSelector(_cmd));
  return nil;
}

@end

@implementation ASTipProvider (Lookup)

+ (NSArray<ASTipProvider *> *)all
{
  static NSArray<ASTipProvider *> *providers;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    providers = @[ [ASLayerBackingTipProvider new] ];
  });
  return providers;
}

@end

#endif // AS_ENABLE_TIPS

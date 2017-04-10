//
//  ASCollectionLayoutContext.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASEqualityHashHelpers.h>

@implementation ASCollectionLayoutContext

- (instancetype)initWithViewportSize:(CGSize)viewportSize elementMap:(ASElementMap *)map
{
  self = [super init];
  if (self) {
    _viewportSize = viewportSize;
    _elementMap = map;
  }
  return self;
}

- (BOOL)isEqualToContext:(ASCollectionLayoutContext *)context
{
  if (context == nil) {
    return NO;
  }
  return CGSizeEqualToSize(_viewportSize, context.viewportSize) && ASObjectIsEqual(_elementMap, context.elementMap);
}

- (BOOL)isEqual:(id)other
{
  if (self == other) {
    return YES;
  }
  if (! [other isKindOfClass:[ASCollectionLayoutContext class]]) {
    return NO;
  }
  return [self isEqualToContext:other];
}

- (NSUInteger)hash
{
  return ASHash64ToNative(ASHashCombine([_elementMap hash], ASCGSizeHash(_viewportSize)));
}

@end

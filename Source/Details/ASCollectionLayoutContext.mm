//
//  ASCollectionLayoutContext.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext+Private.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASEqualityHashHelpers.h>

@implementation ASCollectionLayoutContext

- (instancetype)initWithViewportSize:(CGSize)viewportSize elements:(ASElementMap *)elements additionalInfo:(id)additionalInfo
{
  self = [super init];
  if (self) {
    _viewportSize = viewportSize;
    _elements = elements;
    _additionalInfo = additionalInfo;
  }
  return self;
}

- (BOOL)isEqualToContext:(ASCollectionLayoutContext *)context
{
  if (context == nil) {
    return NO;
  }
  return CGSizeEqualToSize(_viewportSize, context.viewportSize) && ASObjectIsEqual(_elements, context.elements) && ASObjectIsEqual(_additionalInfo, context.additionalInfo);
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
  NSUInteger subhashes[] = {
    ASHashFromCGSize(_viewportSize),
    [_elements hash],
    [_additionalInfo hash]
  };
  return ASIntegerArrayHash(subhashes, sizeof(subhashes) / sizeof(subhashes[0]));
}

@end

//
//  ASCollectionLayoutState.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 9/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASElementMap.h>

@implementation ASCollectionLayoutState

- (instancetype)initWithElementMap:(ASElementMap *)elementMap contentSize:(CGSize)contentSize elementToLayoutArrtibutesMap:(NSMapTable<ASCollectionElement *,UICollectionViewLayoutAttributes *> *)attrsMap
{
  self = [super init];
  if (self) {
    _elementMap = elementMap;
    _contentSize = contentSize;
    _elementToLayoutArrtibutesMap = attrsMap;
  }
  return self;
}

@end

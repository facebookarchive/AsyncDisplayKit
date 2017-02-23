//
//  ASCollectionLayout.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/21/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ASCellNode.h"
#import "ASCollectionLayout.h"
#import "ASCollectionElement.h"
#import "ASElementMap.h"
#import "ASLayout.h"
#import "ASRectTable.h"

@interface ASCollectionLayout ()
@property (nonatomic, strong, readonly) ASElementMap *map;
@property (nonatomic, strong) ASRectTable<ASCollectionElement *> *frameTable;
@property (nonatomic, strong) NSCache <ASCollectionElement *, UICollectionViewLayoutAttributes *> *elementToAttributesCache;
@property (nonatomic) CGSize contentSize;
@end

@implementation ASCollectionLayout

- (instancetype)initWithMap:(ASElementMap *)map size:(CGSize)contentSize frames:(ASRectTable<ASCollectionElement *> *)frames
{
  ASDisplayNodeAssertNotMainThread();
  if (self = [super init]) {
    _map = [map copy];
    _frameTable = [frames copy];
    _elementToAttributesCache = [[NSCache alloc] init];
    _contentSize = contentSize;
  }
  return self;
}

#pragma mark - UICollectionViewLayout Methods

- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
  ASDisplayNodeAssertMainThread();

  NSMutableArray<UICollectionViewLayoutAttributes *> *attrs = [NSMutableArray array];
  for (ASCollectionElement *element in _frameTable) {
    CGRect frame = [self frameForElement:element];
    if (CGRectIntersectsRect(rect, frame)) {
      UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForElement:element];
      [attrs addObject:layoutAttributes];
    }
  }
  return attrs;
}

- (CGSize)collectionViewContentSize
{
  return _contentSize;
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();

  ASCollectionElement *element = [_map elementForItemAtIndexPath:indexPath];
  return [self layoutAttributesForElement:element];
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();

  ASCollectionElement *element = [_map supplementaryElementOfKind:elementKind atIndexPath:indexPath];
  return [self layoutAttributesForElement:element];
}

#pragma mark - Private

- (UICollectionViewLayoutAttributes *)layoutAttributesForElement:(ASCollectionElement *)element
{
  ASDisplayNodeAssertMainThread();

  UICollectionViewLayoutAttributes *result = [_elementToAttributesCache objectForKey:element];
  if (result != nil) {
    return result;
  }
  
  NSIndexPath *indexPath = [_map indexPathForElement:element];
  NSString *elementKind = element.supplementaryElementKind;
  if ([elementKind isEqualToString:ASDataControllerRowNodeKind]) {
    result = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
  } else {
    result = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:elementKind withIndexPath:indexPath];
  }
  result.frame = [self frameForElement:element];
  [_elementToAttributesCache setObject:result forKey:element];
  
  return nil;
}

- (CGRect)frameForElement:(ASCollectionElement *)element
{
  return [_frameTable rectForKey:element];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

@end

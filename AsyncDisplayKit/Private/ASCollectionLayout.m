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
#import "ASLayout.h"

@interface ASCollectionLayout ()
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSArray<ASCollectionElement *> *> *> *elements;
@property (nonatomic, strong) NSMapTable <ASCellNode *, NSValue *> *nodeToRectTable;
@property (nonatomic, strong) NSMapTable <ASCellNode *, NSIndexPath *> *nodeToIndexPathTable;
@property (nonatomic, strong) NSMapTable <ASCellNode *, NSString *> *nodeToElementKindTable;
@property (nonatomic, strong) NSCache <ASCellNode *, UICollectionViewLayoutAttributes *> *nodeToAttributesCache;
@property (nonatomic) CGSize contentSize;
@end

@implementation ASCollectionLayout

- (instancetype)initWithLayout:(ASLayout *)layout elements:(NSDictionary<NSString *, NSArray<NSArray<ASCollectionElement *> *> *> *)elements
{
  ASDisplayNodeAssertNotMainThread();
  if (self = [super init]) {
    // Not a 100% deep copy, but sufficient for now.
    _elements = [[NSDictionary alloc] initWithDictionary:elements copyItems:YES];
    _nodeToRectTable = [NSMapTable mapTableWithKeyOptions:(NSMapTableObjectPointerPersonality | NSMapTableWeakMemory) valueOptions:NSMapTableStrongMemory];
    _nodeToAttributesCache = [[NSCache alloc] init];
    _nodeToIndexPathTable = [NSMapTable mapTableWithKeyOptions:(NSMapTableObjectPointerPersonality | NSMapTableWeakMemory) valueOptions:NSMapTableStrongMemory];
    _nodeToElementKindTable = [NSMapTable mapTableWithKeyOptions:(NSMapTableObjectPointerPersonality | NSMapTableWeakMemory) valueOptions:NSMapTableStrongMemory];
    
    [elements enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull elementKind, NSArray<NSArray<ASCollectionElement *> *> * _Nonnull sections, BOOL * _Nonnull stop) {
      NSInteger s = 0;
      for (NSArray *section in sections) {
        NSInteger i = 0;
        for (ASCollectionElement *element in section) {
          ASCellNode *node = element.nodeIfAllocated;
          ASDisplayNodeAssertNotNil(node, @"Expected all nodes to be allocated before joining a layout.");
          [_nodeToElementKindTable setObject:elementKind forKey:node];
          [_nodeToIndexPathTable setObject:[NSIndexPath indexPathForItem:i inSection:s] forKey:node];
        }
        i++;
      }
      s++;
    }];
    layout = [layout filteredNodeLayoutTree];
    for (ASLayout *sublayout in layout.sublayouts) {
      ASCellNode *node = ASDynamicCast(sublayout.layoutElement, ASCellNode);
      if (node != nil) {
        [_nodeToRectTable setObject:[NSValue valueWithCGRect:sublayout.frame] forKey:node];
      }
    }
    _contentSize = layout.size;
  }
  return self;
}

#pragma mark - UICollectionViewLayout Methods

- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
  NSMutableArray<UICollectionViewLayoutAttributes *> *attrs = [NSMutableArray array];
  for (ASCellNode *node in _nodeToRectTable) {
    CGRect frame = [self frameForNode:node];
    if (CGRectIntersectsRect(rect, frame)) {
      UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForNode:node];
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
  ASCellNode *node = _elements[ASDataControllerRowNodeKind][indexPath.section][indexPath.item].nodeIfAllocated;
  return [self layoutAttributesForNode:node];
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = _elements[elementKind][indexPath.section][indexPath.item].nodeIfAllocated;
  return [self layoutAttributesForNode:node];
}

#pragma mark - Private

- (UICollectionViewLayoutAttributes *)layoutAttributesForNode:(ASCellNode *)node
{
  UICollectionViewLayoutAttributes *result = [_nodeToAttributesCache objectForKey:node];
  if (result != nil) {
    return result;
  }
  
  NSString *elementKind = [_nodeToElementKindTable objectForKey:node];
  NSIndexPath *indexPath = [_nodeToIndexPathTable objectForKey:node];
  if ([elementKind isEqualToString:ASDataControllerRowNodeKind]) {
    result = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
  } else {
    result = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:elementKind withIndexPath:indexPath];
  }
  result.frame = [self frameForNode:node];
  [_nodeToAttributesCache setObject:result forKey:node];
  
  return nil;
}

- (CGRect)frameForNode:(ASCellNode *)node
{
  return [_nodeToRectTable objectForKey:node].CGRectValue;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

@end

//  ASCollectionFlowLayout.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/2/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionFlowLayout.h>
#import <AsyncDisplayKit/ASCollectionLayout+Subclasses.h>

#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutHelpers.h>
#import <AsyncDisplayKit/ASDataControllerLayoutContext.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASStackLayoutSpec.h>

@implementation ASCollectionFlowLayout {
  ASScrollDirection _scrollableDirections;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _scrollableDirections = ASScrollDirectionVerticalDirections;
  }
  return self;
}

- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections
{
  self = [self init];
  if (self) {
    _scrollableDirections = scrollableDirections;
  }
  return self;
}

- (ASSizeRange)sizeRangeThatFits:(CGSize)viewportSize
{
  ASSizeRange sizeRange = ASSizeRangeUnconstrained;
  if (ASScrollDirectionContainsVerticalDirection(_scrollableDirections) == NO) {
    sizeRange.min.height = viewportSize.height;
    sizeRange.max.height = viewportSize.height;
  }
  if (ASScrollDirectionContainsHorizontalDirection(_scrollableDirections) == NO) {
    sizeRange.min.width = viewportSize.width;
    sizeRange.max.width = viewportSize.width;
  }
  return sizeRange;
}

- (ASCollectionLayoutState *)calculateLayoutForLayoutContext:(ASDataControllerLayoutContext *)context
{
  ASElementMap *elementMap = context.elementMap;
  NSMutableArray<ASCellNode *> *children = ASArrayByFlatMapping(elementMap.itemElements, ASCollectionElement *element, element.node);
  if (children.count == 0) {
    return [[ASCollectionLayoutState alloc] initWithElementMap:elementMap
                                                         contentSize:CGSizeZero
                                        elementToLayoutArrtibutesMap:[NSMapTable weakToStrongObjectsMapTable]];
  }
  
  ASStackLayoutSpec *stackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                         spacing:0
                                                                  justifyContent:ASStackLayoutJustifyContentStart
                                                                      alignItems:ASStackLayoutAlignItemsStart
                                                                        flexWrap:ASStackLayoutFlexWrapWrap
                                                                    alignContent:ASStackLayoutAlignContentStart
                                                                        children:children];
  stackSpec.concurrent = YES;
  ASLayout *layout = [stackSpec layoutThatFits:[self sizeRangeThatFits:context.viewportSize]];
  return ASLayoutToCollectionContentAttributes(layout, elementMap);
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
  NSMutableArray *attributesInRect = [NSMutableArray array];
  NSMapTable *attrsMap = self.currentContentAttributes.elementToLayoutArrtibutesMap;
  for (ASCollectionElement *element in attrsMap) {
    UICollectionViewLayoutAttributes *attrs = [attrsMap objectForKey:element];
    if (CGRectIntersectsRect(rect, attrs.frame)) {
      [attributesInRect addObject:attrs];
    }
  }
  return attributesInRect;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionLayoutState *state = self.currentContentAttributes;
  ASCollectionElement *element = [state.elementMap elementForItemAtIndexPath:indexPath];
  return [state.elementToLayoutArrtibutesMap objectForKey:element];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionLayoutState *state = self.currentContentAttributes;
  ASCollectionElement *element = [state.elementMap supplementaryElementOfKind:elementKind atIndexPath:indexPath];
  return [state.elementToLayoutArrtibutesMap objectForKey:element];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  return [self layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
}

@end

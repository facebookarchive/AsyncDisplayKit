//  ASCollectionFlowLayoutDelegate.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/2/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionFlowLayoutDelegate.h>

#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASStackLayoutSpec.h>

@implementation ASCollectionFlowLayoutDelegate {
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

- (id)additionalInfoForLayoutWithElements:(ASElementMap *)elements
{
  return nil;
}

- (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context
{
  ASElementMap *elements = context.elements;
  NSMutableArray<ASCellNode *> *children = ASArrayByFlatMapping(elements.itemElements, ASCollectionElement *element, element.node);
  if (children.count == 0) {
    return [[ASCollectionLayoutState alloc] initWithElements:elements
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
  return [[ASCollectionLayoutState alloc] initWithElements:elements layout:layout];
}

@end

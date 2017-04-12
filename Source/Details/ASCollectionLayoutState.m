//
//  ASCollectionLayoutState.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 9/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutState.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>

@implementation ASCollectionLayoutState

- (instancetype)initWithElements:(ASElementMap *)elements layout:(ASLayout *)layout
{
  NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *attrsMap = [NSMapTable mapTableWithKeyOptions:(NSMapTableObjectPointerPersonality | NSMapTableWeakMemory) valueOptions:NSMapTableStrongMemory];
  for (ASLayout *sublayout in layout.sublayouts) {
    ASCollectionElement *element = ((ASCellNode *)sublayout.layoutElement).collectionElement;
    NSIndexPath *indexPath = [elements indexPathForElement:element];
    NSString *supplementaryElementKind = element.supplementaryElementKind;
    
    UICollectionViewLayoutAttributes *attrs;
    if (supplementaryElementKind == nil) {
      attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    } else {
      attrs = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:supplementaryElementKind withIndexPath:indexPath];
    }
    
    attrs.frame = sublayout.frame;
    [attrsMap setObject:attrs forKey:element];
  }

  return [self initWithElements:elements contentSize:layout.size elementToLayoutArrtibutesMap:attrsMap];
}

- (instancetype)initWithElements:(ASElementMap *)elements contentSize:(CGSize)contentSize elementToLayoutArrtibutesMap:(NSMapTable<ASCollectionElement *,UICollectionViewLayoutAttributes *> *)attrsMap
{
  self = [super init];
  if (self) {
    _elements = elements;
    _contentSize = contentSize;
    _elementToLayoutArrtibutesMap = attrsMap;
  }
  return self;
}

@end

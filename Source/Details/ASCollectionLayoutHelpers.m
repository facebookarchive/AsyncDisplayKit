//
//  ASCollectionLayoutHelpers.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 24/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutHelpers.h>

#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASCollectionContentAttributes.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>

ASCollectionContentAttributes *ASLayoutToCollectionContentAttributes(ASLayout *layout, ASElementMap *elementMap)
{
  NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *attrsMap = [NSMapTable weakToStrongObjectsMapTable];
  for (ASLayout *sublayout in layout.sublayouts) {
    ASCollectionElement *element = ((ASCellNode *)sublayout.layoutElement).collectionElement;
    NSIndexPath *indexPath = [elementMap indexPathForElement:element];
    
    UICollectionViewLayoutAttributes *attrs;
    if (element.supplementaryElementKind == nil) {
      attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    } else {
      attrs = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:element.supplementaryElementKind withIndexPath:indexPath];
    }
    
    attrs.frame = sublayout.frame;
    [attrsMap setObject:attrs forKey:element];
  }
  
  return [[ASCollectionContentAttributes alloc] initWithElementMap:elementMap contentSize:layout.size elementToLayoutArrtibutesMap:attrsMap];
}


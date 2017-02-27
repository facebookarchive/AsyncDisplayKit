//
//  AsyncDisplayKit+IGListKitMethods.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/27/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import "AsyncDisplayKit+IGListKitMethods.h"
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/_ASCollectionViewCell.h>

@implementation ASIGListSectionControllerMethods

+ (__kindof UICollectionViewCell *)cellForItemAtIndex:(NSInteger)index sectionController:(IGListSectionController<IGListSectionType> *)sectionController
{
  return [sectionController.collectionContext dequeueReusableCellOfClass:[_ASCollectionViewCell class] forSectionController:sectionController atIndex:index];
}

+ (CGSize)sizeForItemAtIndex:(NSInteger)index
{
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd));
  return CGSizeZero;
}

@end

@implementation ASIGListSupplementaryViewSourceMethods

+ (__kindof UICollectionReusableView *)viewForSupplementaryElementOfKind:(NSString *)elementKind
                                                                 atIndex:(NSInteger)index
                                                       sectionController:(IGListSectionController<IGListSectionType> *)sectionController
{
  return [sectionController.collectionContext dequeueReusableSupplementaryViewOfKind:elementKind forSectionController:sectionController class:[UICollectionReusableView class] atIndex:index];
}

/**
 * The implementation of sizeForSupplementaryViewOfKind that connects
 * IGSupplementaryViewSource to AsyncDisplayKit. Add this into the .m file
 * for your `ASIGListSupplementaryViewSource` and implement the ASDK-specific
 * method `nodeForSupplementaryElementOfKind:` to provide your node which should
 * size itself. You can set `node.style.preferredSize` if you want to fix the size.
 *
 * @param sectionController The section controller this supplementary source is
 * working on behalf of. For example, `self` or `self.sectionController`.
 */
+ (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index
{
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd));
  return CGSizeZero;
}

@end

#endif // IG_LIST_KIT

//
//  AsyncDisplayKit+IGListKitMethods.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/27/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_IG_LIST_KIT

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

+ (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index
{
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd));
  return CGSizeZero;
}

@end

#endif // AS_IG_LIST_KIT

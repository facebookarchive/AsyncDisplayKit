//
//  ASIGListKitMethodImplementations.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

/**
 * If you are using AsyncDisplayKit with IGListKit, you should use
 * these macros to provide implementations of methods like 
 * -cellForItemAtIndex: that don't apply when used with AsyncDisplayKit.
 *
 * Your section controllers should also conform to @c ASSectionController and your
 * supplementary view sources should conform to @c ASSupplementaryNodeSource.
 */

#if IG_LIST_KIT

#import <AsyncDisplayKit/_ASCollectionViewCell.h>

/**
 * The implementation of viewForSupplementaryElementOfKind that connects
 * IGSupplementaryViewSource to AsyncDisplayKit. Add this into the .m file
 * for your `ASIGListSupplementaryViewSource` and implement the ASDK-specific
 * method `nodeForSupplementaryElementOfKind:` to provide your node.
 *
 * @param sectionController The section controller this supplementary source is
 * working on behalf of. For example, `self` or `self.sectionController`.
 */
#define ASIGSupplementarySourceViewForSupplementaryElementImplementation(sectionController) \
- (__kindof UICollectionReusableView *)viewForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index { \
  return [self.collectionContext dequeueReusableSupplementaryViewOfKind:elementKind forSectionController:sectionController class:[UICollectionReusableView class] atIndex:index]; \
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
#define ASIGSupplementarySourceSizeForSupplementaryElementImplementation \
- (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index {\
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd)); \
  return CGSizeZero; \
}


#define ASIGSectionControllerCellForIndexImplementation \
- (__kindof UICollectionViewCell *)cellForItemAtIndex:(NSInteger)index\
{\
  return [self.collectionContext dequeueReusableCellOfClass:[_ASCollectionViewCell class] forSectionController:self atIndex:index]; \
}\

#define ASIGSectionControllerSizeForItemImplementation \
- (CGSize)sizeForItemAtIndex:(NSInteger)index \
{\
  ASDisplayNodeFailAssert(@"Did not expect %@ to be called.", NSStringFromSelector(_cmd)); \
  return CGSizeZero;\
}

#endif // IG_LIST_KIT

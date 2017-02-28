//
//  ASMutableElementMap.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/23/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASElementMap.h>

NS_ASSUME_NONNULL_BEGIN

@class ASSection, ASCollectionElement;

/**
 * This mutable version will be removed in the future. It's only here now to keep the diff small
 * as we port data controller to use ASElementMap.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASMutableElementMap : NSObject <NSCopying>

- (instancetype)init __unavailable;

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections items:(ASCollectionElementTwoDimensionalArray *)items supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements;

- (void)insertSection:(ASSection *)section atIndex:(NSInteger)index;

- (void)removeAllSectionContexts;

/// Only modifies the array of ASSection * objects
- (void)removeSectionContextsAtIndexes:(NSIndexSet *)indexes;

- (void)removeAllElements;

- (void)removeItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (void)removeSectionsOfItems:(NSIndexSet *)itemSections;

- (void)removeSupplementaryElementsInSections:(NSIndexSet *)sections;

- (void)insertEmptySectionsOfItemsAtIndexes:(NSIndexSet *)sections;

- (void)insertElement:(ASCollectionElement *)element atIndexPath:(NSIndexPath *)indexPath;

@end

@interface ASElementMap (MutableCopying) <NSMutableCopying>
@end

NS_ASSUME_NONNULL_END

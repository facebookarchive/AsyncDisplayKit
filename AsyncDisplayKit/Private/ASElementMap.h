//
//  ASElementMap.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/22/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionElement, ASSection;
@protocol ASSectionContext;

AS_SUBCLASSING_RESTRICTED
@interface ASElementMap : NSObject <NSCopying, NSMutableCopying>

@property (readonly) NSInteger numberOfSections;

- (NSInteger)numberOfItemsInSection:(NSInteger)section;

- (nullable id<ASSectionContext>)contextForSection:(NSInteger)section;

@property (copy, readonly) NSArray<NSIndexPath *> *itemIndexPaths;

@property (copy, readonly) NSArray<NSString *> *supplementaryElementKinds;

- (NSIndexPath *)convertIndexPath:(NSIndexPath *)indexPath fromMap:(ASElementMap *)map;

/**
 * O(1)
 */
- (nullable NSIndexPath *)indexPathForElement:(ASCollectionElement *)element;

/**
 * O(1)
 */
- (nullable ASCollectionElement *)elementForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * O(1)
 */
- (nullable ASCollectionElement *)supplementaryElementOfKind:(NSString *)supplementaryElementKind atIndexPath:(NSIndexPath *)indexPath;

- (void)enumerateUsingBlock:(AS_NOESCAPE void(^)(NSIndexPath *indexPath, ASCollectionElement *element, BOOL *stop))block;

@end

/**
 * This mutable version will be removed in the future. It's only here now to keep the diff small
 * as we port data controller to use this.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASMutableElementMap : NSObject <NSCopying>

- (void)insertSection:(ASSection *)section atIndex:(NSInteger)index;

- (void)removeAllSectionContexts;

/// Only modifies the array of ASSection * objects
- (void)removeSectionContextsAtIndexes:(NSIndexSet *)indexes;

- (void)removeAllElements;

- (void)removeItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (void)removeElementsOfKind:(NSString *)kind inSections:(NSIndexSet *)sections;

- (void)insertEmptySectionsOfItemsAtIndexes:(NSIndexSet *)sections;

- (void)insertElement:(ASCollectionElement *)element atIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END

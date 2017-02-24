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

typedef NSArray<NSArray<ASCollectionElement *> *> ASCollectionElementTwoDimensionalArray;

// ElementKind -> IndexPath -> Element
typedef NSDictionary<NSString *, NSDictionary<NSIndexPath *, ASCollectionElement *> *> ASSupplementaryElementDictionary;

AS_SUBCLASSING_RESTRICTED
@interface ASElementMap : NSObject <NSCopying, NSMutableCopying>

- (instancetype)initWithSections:(NSArray<ASSection *> *)sections
                           items:(ASCollectionElementTwoDimensionalArray *)items
           supplementaryElements:(ASSupplementaryElementDictionary *)supplementaryElements;

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

NS_ASSUME_NONNULL_END

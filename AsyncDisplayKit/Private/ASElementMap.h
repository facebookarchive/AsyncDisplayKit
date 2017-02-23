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

@class ASCollectionElement, ASCellNode, ASSection, _ASHierarchyChangeSet;
@protocol ASDataControllerSource;

AS_SUBCLASSING_RESTRICTED
@interface ASElementMap : NSObject <NSCopying>

- (instancetype)init __unavailable;

@property (class, nonatomic, strong, readonly) ASElementMap *emptyMap;

@property (nonatomic, strong, readonly) NSArray<ASSection *> *sections;

- (NSInteger)numberOfItemsInSection:(NSInteger)section;

@property (nonatomic, readonly) NSArray<NSString *> *supplementaryElementKinds;

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

@interface ASElementMap (Operations)

- (instancetype)initFromDataSource:(id<ASDataControllerSource>)dataSource;

- (instancetype)initWithPreviousMap:(ASElementMap *)previousMap
                          changeSet:(_ASHierarchyChangeSet *)changeSet
                         dataSource:(id<ASDataControllerSource>)dataSource;

@end

NS_ASSUME_NONNULL_END

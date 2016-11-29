//
//  ASCollectionItem.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 11/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#pragma once
#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASDimension.h>

@class ASCellNode;

NS_ASSUME_NONNULL_BEGIN

typedef NSString * ASSectionIdentifier;
typedef NSString * ASItemIdentifier;
typedef NSString * ASSupplementaryElementKind;

/**
 * ASCellNode creation block. Used to lazily create the ASCellNode instance for an item.
 */
typedef ASCellNode * _Nonnull(^ASCellNodeBlock)();

@protocol ASCollectionItem <NSObject>

/**
 * The identifier for the item.
 */
@property (nonatomic, strong, readonly) ASItemIdentifier identifier;

@end

@protocol ASCollectionSection <NSObject>

/**
 * The identifier for the section.
 */
@property (nonatomic, strong, readonly) ASSectionIdentifier identifier;

/**
 * The items in the section. You can use this property to get fine-grained control over the collection data.
 */
@property (nonatomic, strong, readonly) NSMutableArray<id<ASCollectionItem>> *mutableItems;

@end

/**
 * An object used to construct the data set for a collection
 * or table node. 
 * When the collection needs to update its data, it calls @c dataForCollectionNode:
 * on the data source. The data source calls @c createNewData on the collection node,
 * configures the data object, and returns it.
 */
@interface ASCollectionData : NSObject

/**
 * Appends a section to the collection.
 *
 * @param identifier The identifier for the section.
 * @param block A block in which to configure the section.
 *
 * @warning It is an error to call this method with an identifier that is associated with another section.
 */
- (void)addSectionWithIdentifier:(ASSectionIdentifier)identifier
                           block:(__attribute((noescape)) void(^)(ASCollectionData * data))block;

/**
 * Adds an item to the current section. If this method is called outside of an addSectionWithIdentifier:
 * block, a default section will be created and used.
 *
 * @param identifier The identifier for the new item.
 * @param nodeBlock A block that will be used to construct the node for the item.
 *
 * @note If an item already exists with this identifier, the node block will be ignored.
 * @note It is more performant to specify the node block inline here, rather than calling a method that generates it, but the difference is not prohibitive.
 */
- (void)addItemWithIdentifier:(ASItemIdentifier)identifier
                    nodeBlock:(ASCellNodeBlock)nodeBlock;

/**
 * Adds a supplementary element to the current section. If this method is called outside of an addSectionWithIdentifier:
 * block, a default section will be created and used.
 *
 * @param elementKind The kind of supplementary element to add.
 * @param identifier The identifier for the new item.
 * @param index The index for the supplementary element. This can be @c NSNotFound.
 * @param nodeBlock A block that will be used to construct the node for the supplementary element.
 *
 * @note If an element already exists with this identifier, the node block will be ignored.
 * @note It is more performant to specify the node block inline here, rather than calling a method that generates it, but the difference is not prohibitive.
 */
- (void)addSupplementaryElementOfKind:(NSString *)elementKind
                       withIdentifier:(ASItemIdentifier)identifier
                                index:(NSInteger)index
                            nodeBlock:(ASCellNodeBlock)nodeBlock;

/**
 * Finds or creates an item with the given identifier.
 *
 * @param identifier The identifier for the item.
 * @param nodeBlock A block that will be used to construct the node for the item.
 *
 * You can use this method to get more fine-grained control over the collection data.
 * The returned item can be inserted into the @c mutableItems of an @c ASCollectionSection.
 *
 * Note that if an item already exists with this identifier, the node block will be ignored.
 * @note It is more performant to specify the node block inline here, rather than calling a method that generates it, but the difference is not prohibitive.
 */
- (id<ASCollectionItem>)itemWithIdentifier:(ASItemIdentifier)identifier
                                 nodeBlock:(ASCellNodeBlock)nodeBlock;

/**
 * Finds or creates a section with the given identifier.
 *
 * @param identifier The identifier for the section.
 *
 * You can use this method to get more fine-grained control over the collection data.
 * The returned section can be inserted into @c mutableSections.
 */
- (id<ASCollectionSection>)sectionWithIdentifier:(ASSectionIdentifier)identifier;

/**
 * The sections in the collection. You can use this property to get fine-grained control over the collection data.
 */
@property (nonatomic, strong, readonly) NSMutableArray<id<ASCollectionSection>> *mutableSections;

@end

NS_ASSUME_NONNULL_END

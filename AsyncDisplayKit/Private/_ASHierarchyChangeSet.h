//
//  _ASHierarchyChangeSet.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/29/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSUInteger ASDataControllerAnimationOptions;

typedef NS_ENUM(NSInteger, _ASHierarchyChangeType) {
  _ASHierarchyChangeTypeReload,
  _ASHierarchyChangeTypeDelete,
  _ASHierarchyChangeTypeInsert
};

NSString *NSStringFromASHierarchyChangeType(_ASHierarchyChangeType changeType);

@interface _ASHierarchySectionChange : NSObject

// FIXME: Generalize this to `changeMetadata` dict?
@property (nonatomic, readonly) ASDataControllerAnimationOptions animationOptions;

@property (nonatomic, strong, readonly) NSIndexSet *indexSet;
@property (nonatomic, readonly) _ASHierarchyChangeType changeType;
@end

@interface _ASHierarchyItemChange : NSObject
@property (nonatomic, readonly) ASDataControllerAnimationOptions animationOptions;

/// Index paths are sorted descending for changeType .Delete, ascending otherwise
@property (nonatomic, strong, readonly) NSArray<NSIndexPath *> *indexPaths;

@property (nonatomic, readonly) _ASHierarchyChangeType changeType;

+ (NSDictionary *)sectionToIndexSetMapFromChanges:(NSArray<_ASHierarchyItemChange *> *)changes ofType:(_ASHierarchyChangeType)changeType;
@end

@interface _ASHierarchyChangeSet : NSObject

/// @precondition The change set must be completed.
@property (nonatomic, strong, readonly) NSIndexSet *deletedSections;
/// @precondition The change set must be completed.
@property (nonatomic, strong, readonly) NSIndexSet *insertedSections;

/**
 Get the section index after the update for the given section before the update.
 
 @precondition The change set must be completed.
 @returns The new section index, or NSNotFound if the given section was deleted.
 */
- (NSUInteger)newSectionForOldSection:(NSUInteger)oldSection;

@property (nonatomic, readonly) BOOL completed;

/// Call this once the change set has been constructed to prevent future modifications to the changeset. Calling this more than once is a programmer error.
/// NOTE: Calling this method will cause the changeset to convert all reloads into delete/insert pairs.
- (void)markCompleted;

/**
 @abstract Return sorted changes of the given type, grouped by animation options.
 
 Items deleted from deleted sections are not reported.
 Items inserted into inserted sections are not reported.
 Items reloaded in reloaded sections are not reported.
 
 The safe order for processing change groups is:
 - Reloaded sections & reloaded items
 - Deleted items, descending order
 - Deleted sections, descending order
 - Inserted sections, ascending order
 - Inserted items, ascending order
 */
- (nullable NSArray <_ASHierarchySectionChange *> *)sectionChangesOfType:(_ASHierarchyChangeType)changeType;
- (nullable NSArray <_ASHierarchyItemChange *> *)itemChangesOfType:(_ASHierarchyChangeType)changeType;

/// Returns all item indexes affected by changes of the given type in the given section.
- (NSIndexSet *)indexesForItemChangesOfType:(_ASHierarchyChangeType)changeType inSection:(NSUInteger)section;

- (void)deleteSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options;
- (void)insertSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options;
- (void)reloadSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options;
- (void)insertItems:(NSArray<NSIndexPath *> *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options;
- (void)deleteItems:(NSArray<NSIndexPath *> *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options;
- (void)reloadItems:(NSArray<NSIndexPath *> *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options;
@end

NS_ASSUME_NONNULL_END

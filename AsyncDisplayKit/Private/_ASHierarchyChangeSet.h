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
#import <vector>

NS_ASSUME_NONNULL_BEGIN

typedef NSUInteger ASDataControllerAnimationOptions;

typedef NS_ENUM(NSInteger, _ASHierarchyChangeType) {
  /**
   * A reload change, as submitted by the user. When a change set is
   * completed, these changes are decomposed into delete-insert pairs
   * and combined with the original deletes and inserts of the change.
   */
  _ASHierarchyChangeTypeReload,
  
  /**
   * A change that was either an original delete, or the first 
   * part of a decomposed reload.
   */
  _ASHierarchyChangeTypeDelete,
  
  /**
   * A change that was submitted by the user as a delete.
   */
  _ASHierarchyChangeTypeOriginalDelete,
  
  /**
   * A change that was either an original insert, or the second
   * part of a decomposed reload.
   */
  _ASHierarchyChangeTypeInsert,
  
  /**
   * A change that was submitted by the user as an insert.
   */
  _ASHierarchyChangeTypeOriginalInsert
};

/**
 * Returns YES if the given change type is either .Insert or .Delete, NO otherwise.
 * Other change types – .Reload, .OriginalInsert, .OriginalDelete – are
 * intermediary types used while building the change set. All changes will
 * be reduced to either .Insert or .Delete when the change is marked completed.
 */
BOOL ASHierarchyChangeTypeIsFinal(_ASHierarchyChangeType changeType);

NSString *NSStringFromASHierarchyChangeType(_ASHierarchyChangeType changeType);

@interface _ASHierarchySectionChange : NSObject

// FIXME: Generalize this to `changeMetadata` dict?
@property (nonatomic, readonly) ASDataControllerAnimationOptions animationOptions;

@property (nonatomic, strong, readonly) NSIndexSet *indexSet;
@property (nonatomic, readonly) _ASHierarchyChangeType changeType;

/**
 * If this is a .OriginalInsert or .OriginalDelete change, this returns a copied change
 * with type .Insert or .Delete. Calling this on changes of other types is an error.
 */
- (_ASHierarchySectionChange *)changeByFinalizingType;
@end

@interface _ASHierarchyItemChange : NSObject
@property (nonatomic, readonly) ASDataControllerAnimationOptions animationOptions;

/// Index paths are sorted descending for changeType .Delete, ascending otherwise
@property (nonatomic, strong, readonly) NSArray<NSIndexPath *> *indexPaths;

@property (nonatomic, readonly) _ASHierarchyChangeType changeType;

+ (NSDictionary *)sectionToIndexSetMapFromChanges:(NSArray<_ASHierarchyItemChange *> *)changes ofType:(_ASHierarchyChangeType)changeType;

/**
 * If this is a .OriginalInsert or .OriginalDelete change, this returns a copied change
 * with type .Insert or .Delete. Calling this on changes of other types is an error.
 */
- (_ASHierarchyItemChange *)changeByFinalizingType;
@end

@interface _ASHierarchyChangeSet : NSObject

- (instancetype)initWithOldData:(std::vector<NSInteger>)oldItemCounts NS_DESIGNATED_INITIALIZER;

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
- (void)markCompletedWithNewItemCounts:(std::vector<NSInteger>)newItemCounts;

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

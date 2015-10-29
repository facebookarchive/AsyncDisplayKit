//
//  _ASHierarchyChangeSet.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/29/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASDataController.h"

typedef NS_ENUM(NSInteger, _ASHierarchyChangeType) {
  _ASHierarchyChangeTypeReload,
  _ASHierarchyChangeTypeDelete,
  _ASHierarchyChangeTypeInsert
};

@interface _ASHierarchySectionChange : NSObject

// FIXME: Generalize this to `changeMetadata` dict?
@property (nonatomic, readonly) ASDataControllerAnimationOptions animationOptions;

@property (nonatomic, strong, readonly) NSIndexSet *indexSet;
@property (nonatomic, readonly) _ASHierarchyChangeType changeType;
@end

@interface _ASHierarchyItemChange : NSObject
@property (nonatomic, readonly) ASDataControllerAnimationOptions animationOptions;

/// Index paths are sorted descending for changeType .Delete, ascending otherwise
@property (nonatomic, strong, readonly) NSArray *indexPaths;
@property (nonatomic, readonly) _ASHierarchyChangeType changeType;
@end

@interface _ASHierarchyChangeSet : NSObject

@property (nonatomic, strong, readonly) NSIndexSet *deletedSections;
@property (nonatomic, strong, readonly) NSIndexSet *insertedSections;
@property (nonatomic, strong, readonly) NSIndexSet *reloadedSections;
@property (nonatomic, strong, readonly) NSArray *insertedItems;
@property (nonatomic, strong, readonly) NSArray *deletedItems;
@property (nonatomic, strong, readonly) NSArray *reloadedItems;

@property (nonatomic, readonly) BOOL completed;

/// Call this once the change set has been constructed to prevent future modifications to the changeset. Calling this more than once is a programmer error.
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
- (NSArray /*<_ASHierarchySectionChange *>*/ *)sectionChangesOfType:(_ASHierarchyChangeType)changeType;
- (NSArray /*<_ASHierarchyItemChange *>*/ *)itemChangesOfType:(_ASHierarchyChangeType)changeType;

- (void)deleteSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options;
- (void)insertSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options;
- (void)reloadSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options;
- (void)insertItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options;
- (void)deleteItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options;
- (void)reloadItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options;
@end

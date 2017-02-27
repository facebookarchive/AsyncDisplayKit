//
//  NSIndexSet+ASHelpers.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 6/23/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSIndexSet (ASHelpers)

- (NSIndexSet *)as_indexesByMapping:(NSUInteger (^)(NSUInteger idx))block;

- (NSIndexSet *)as_intersectionWithIndexes:(NSIndexSet *)indexes;

/// Returns all the item indexes from the given index paths that are in the given section.
+ (NSIndexSet *)as_indexSetFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths inSection:(NSUInteger)section;

/// If you've got an old index, and you insert items using this index set, this returns the change to get to the new index.
- (NSUInteger)as_indexChangeByInsertingItemsBelowIndex:(NSUInteger)index;

- (NSString *)as_smallDescription;

/// Returns all the section indexes contained in the index paths array.
+ (NSIndexSet *)as_sectionsFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (NSArray<NSIndexPath *> *)as_filterIndexPathsBySection:(id<NSFastEnumeration>)indexPaths;

@end

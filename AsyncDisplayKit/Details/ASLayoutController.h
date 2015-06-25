/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASScrollDirection.h>


typedef struct {
  CGFloat leadingBufferScreenfuls;
  CGFloat trailingBufferScreenfuls;
} ASRangeTuningParameters;

@protocol ASLayoutController <NSObject>

/**
 * Tuning parameters for the range.
 *
 * Defaults to a trailing buffer of one screenful and a leading buffer of two screenfuls.
 */
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType;

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType;

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType;

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters ASDISPLAYNODE_DEPRECATED;

- (BOOL)shouldUpdateForVisibleIndexPath:(NSArray *)indexPath viewportSize:(CGSize)viewportSize ASDISPLAYNODE_DEPRECATED;

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize ASDISPLAYNODE_DEPRECATED;

@optional

- (void)insertNodesAtIndexPaths:(NSArray *)indexPaths withSizes:(NSArray *)nodeSizes;

- (void)deleteNodesAtIndexPaths:(NSArray *)indexPaths;

- (void)insertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet;

- (void)deleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths;

@end

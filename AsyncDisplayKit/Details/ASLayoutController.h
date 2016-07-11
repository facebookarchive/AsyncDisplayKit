//
//  ASLayoutController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCellNode;

typedef struct {
  CGFloat leadingBufferScreenfuls;
  CGFloat trailingBufferScreenfuls;
} ASRangeTuningParameters;

FOUNDATION_EXPORT ASRangeTuningParameters const ASRangeTuningParametersZero;

FOUNDATION_EXPORT BOOL ASRangeTuningParametersEqualToRangeTuningParameters(ASRangeTuningParameters lhs, ASRangeTuningParameters rhs);

@protocol ASLayoutController <NSObject>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

@optional

- (void)insertNodesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withSizes:(NSArray<NSValue *> *)nodeSizes;

- (void)deleteNodesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (void)insertSections:(NSArray<NSArray <ASCellNode *>*> *)sections atIndexSet:(NSIndexSet *)indexSet;

- (void)deleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

- (void)setVisibleNodeIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (void)setViewportSize:(CGSize)viewportSize;
- (CGSize)viewportSize;

@end

NS_ASSUME_NONNULL_END

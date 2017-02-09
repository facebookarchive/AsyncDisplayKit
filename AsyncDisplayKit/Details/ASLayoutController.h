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

ASDISPLAYNODE_EXTERN_C_BEGIN

typedef struct {
  CGFloat leadingBufferScreenfuls;
  CGFloat trailingBufferScreenfuls;
} ASRangeTuningParameters;

struct ASDirectionalScreenfulBuffer {
  CGFloat positiveDirection; // Positive relative to iOS Core Animation layer coordinate space.
  CGFloat negativeDirection;
};
typedef struct ASDirectionalScreenfulBuffer ASDirectionalScreenfulBuffer;

ASDISPLAYNODE_EXTERN_C_END

@protocol ASLayoutController <NSObject>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (NSSet<NSIndexPath *> *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

@optional

- (void)setVisibleNodeIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

- (void)setViewportSize:(CGSize)viewportSize;
- (CGSize)viewportSize;

@end

NS_ASSUME_NONNULL_END

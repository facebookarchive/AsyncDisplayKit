/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASLayoutController.h"
#import "ASBaseDefines.h"
#import "ASDataController.h"

typedef NS_ENUM (NSUInteger, ASCollectionViewWaterfallLayoutItemRenderDirection) {
    ASCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst,//cannot support insert in the middle!!!
    ASCollectionViewWaterfallLayoutItemRenderDirectionLeftToRight,
    ASCollectionViewWaterfallLayoutItemRenderDirectionRightToLeft
};

typedef NS_ENUM(NSUInteger, ASWaterfallLayoutDirection) {
    ASWaterfallLayoutDirectionVertical,
    ASWaterfallLayoutDirectionHorizontal,
};

/**
 * The controller for water fall layout.
 */
@interface ASWaterfallLayoutController : UICollectionViewLayout <ASLayoutController>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType;

@property (nonatomic, readonly, assign) ASWaterfallLayoutDirection layoutDirection;

- (instancetype)init;

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters ASDISPLAYNODE_DEPRECATED;

@property (nonatomic, assign) NSInteger columnCount;

@property (nonatomic,assign) UICollectionViewScrollDirection scrollDirection;

@property (nonatomic, assign) ASCollectionViewWaterfallLayoutItemRenderDirection itemRenderDirection;

@property (nonatomic, assign) ASDataController *dataController;

@end

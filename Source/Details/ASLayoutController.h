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

@protocol ASLayoutController <NSObject>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (void)indexPathsForScrolling:(ASScrollDirection)scrollDirection
                     rangeMode:(ASLayoutRangeMode)rangeMode
             visibleIndexPaths:(out NSSet<NSIndexPath *> * _Nullable * _Nonnull)visibleIndexPaths
             displayIndexPaths:(out NSSet<NSIndexPath *> * _Nullable * _Nonnull)displayIndexPaths
             preloadIndexPaths:(out NSSet<NSIndexPath *> * _Nullable * _Nonnull)preloadIndexPaths;

@end

NS_ASSUME_NONNULL_END

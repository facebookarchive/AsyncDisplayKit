//
//  ASFlowLayoutController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAbstractLayoutController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCellNode;

typedef NS_ENUM(NSUInteger, ASFlowLayoutDirection) {
  ASFlowLayoutDirectionVertical,
  ASFlowLayoutDirectionHorizontal,
};

@protocol ASFlowLayoutControllerDataSource

- (NSArray<NSArray <ASCellNode *> *> *)completedNodes;  // This provides access to ASDataController's _completedNodes multidimensional array.

@end

/**
 *  An optimized flow layout controller that supports only vertical or horizontal scrolling, not simultaneously two-dimensional scrolling.
 *  It is used for all ASTableViews, and may be used with ASCollectionView.
 */
@interface ASFlowLayoutController : ASAbstractLayoutController

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;
@property (nonatomic, readwrite, weak) id <ASFlowLayoutControllerDataSource> dataSource;

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection;

@end

NS_ASSUME_NONNULL_END

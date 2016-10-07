//
//  ASCollectionNode.h
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UICollectionView.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>
#import <AsyncDisplayKit/ASCollectionView.h>

@protocol ASCollectionViewLayoutFacilitatorProtocol;
@protocol ASCollectionDelegate;
@protocol ASCollectionDataSource;
@class ASCollectionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * ASCollectionNode is a node based class that wraps an ASCollectionView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASCollectionNode : ASDisplayNode <ASRangeControllerUpdateRangeProtocol>

/**
 * Initializes an ASCollectionNode
 *
 * @discussion Initializes and returns a newly allocated collection node object with the specified layout.
 *
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout;

/**
 * Initializes an ASCollectionNode
 *
 * @discussion Initializes and returns a newly allocated collection node object with the specified frame and layout.
 *
 * @param frame The frame rectangle for the collection view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This frame is passed to the superclass during initialization.
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout;

/**
 * Returns the corresponding ASCollectionView
 *
 * @return view The corresponding ASCollectionView.
 */
@property (strong, nonatomic, readonly) ASCollectionView *view;

/**
 * The object that acts as the asynchronous delegate of the collection view
 *
 * @discussion The delegate must adopt the ASCollectionDelegate protocol. The collection view maintains a weak reference to the delegate object.
 *
 * The delegate object is responsible for providing size constraints for nodes and indicating whether batch fetching should begin.
 * @note This is a convenience method which sets the asyncDelegate on the collection node's collection view.
 */
@property (weak, nonatomic) id <ASCollectionDelegate>   delegate;

/**
 * The object that acts as the asynchronous data source of the collection view
 *
 * @discussion The datasource must adopt the ASCollectionDataSource protocol. The collection view maintains a weak reference to the datasource object.
 *
 * The datasource object is responsible for providing nodes or node creation blocks to the collection view.
 * @note This is a convenience method which sets the asyncDatasource on the collection node's collection view.
 */
@property (weak, nonatomic) id <ASCollectionDataSource> dataSource;

/**
 * Tuning parameters for a range type in full mode.
 *
 * @param rangeType The range type to get the tuning parameters for.
 *
 * @return A tuning parameter value for the given range type in full mode.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT;

/**
 * Set the tuning parameters for a range type in full mode.
 *
 * @param tuningParameters The tuning parameters to store for a range type.
 * @param rangeType The range type to set the tuning parameters for.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

/**
 * Tuning parameters for a range type in the specified mode.
 *
 * @param rangeMode The range mode to get the running parameters for.
 * @param rangeType The range type to get the tuning parameters for.
 *
 * @return A tuning parameter value for the given range type in the given mode.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT;

/**
 * Set the tuning parameters for a range type in the specified mode.
 *
 * @param tuningParameters The tuning parameters to store for a range type.
 * @param rangeMode The range mode to set the running parameters for.
 * @param rangeType The range type to set the tuning parameters for.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadDataWithCompletion:(nullable void (^)())completion;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadData;

/**
 * Reload everything from scratch entirely on the main thread, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version and will block the main thread
 * while all the cells load.
 */
- (void)reloadDataImmediately;

@end

NS_ASSUME_NONNULL_END

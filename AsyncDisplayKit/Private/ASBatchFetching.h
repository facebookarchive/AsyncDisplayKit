//
//  ASBatchFetching.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import "ASBatchContext.h"
#import "ASScrollDirection.h"

ASDISPLAYNODE_EXTERN_C_BEGIN

@protocol ASBatchFetchingScrollView <NSObject>

- (BOOL)canBatchFetch;
- (ASBatchContext *)batchContext;
- (CGFloat)leadingScreensForBatching;

@end

/**
 @abstract Determine if batch fetching should begin based on the state of the parameters.
 @discussion This method is broken into a category for unit testing purposes and should be used with the ASTableView and
 * ASCollectionView batch fetching API.
 @param context The scroll view that in-flight fetches are happening.
 @param scrollDirection The current scrolling direction of the scroll view.
 @param targetOffset The offset that the scrollview will scroll to.
 @return Whether or not the current state should proceed with batch fetching.
 */
BOOL ASDisplayShouldFetchBatchForScrollView(UIScrollView<ASBatchFetchingScrollView> *scrollView, ASScrollDirection scrollDirection, CGPoint contentOffset);


/**
 @abstract Determine if batch fetching should begin based on the state of the parameters.
 @param context The batch fetching context that contains knowledge about in-flight fetches.
 @param scrollDirection The current scrolling direction of the scroll view.
 @param bounds The bounds of the scrollview.
 @param contentSize The content size of the scrollview.
 @param targetOffset The offset that the scrollview will scroll to.
 @param leadingScreens How many screens in the remaining distance will trigger batch fetching.
 @return Whether or not the current state should proceed with batch fetching.
 @discussion This method is broken into a category for unit testing purposes and should be used with the ASTableView and
 * ASCollectionView batch fetching API.
 */
extern BOOL ASDisplayShouldFetchBatchForContext(ASBatchContext *context,
                                                ASScrollDirection scrollDirection,
                                                CGRect bounds,
                                                CGSize contentSize,
                                                CGPoint targetOffset,
                                                CGFloat leadingScreens);

ASDISPLAYNODE_EXTERN_C_END

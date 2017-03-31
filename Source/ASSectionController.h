//
//  ASSectionController.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDimension.h>

NS_ASSUME_NONNULL_BEGIN

@class ASBatchContext;

/**
 * A protocol that your section controllers should conform to,
 * in addition to IGListSectionType, in order to be used with AsyncDisplayKit.
 *
 * @note Your supplementary view source should conform to @c ASSupplementaryNodeSource.
 */
@protocol ASSectionController <NSObject>

/**
 * A method to provide the node block for the item at the given index.
 * The node block you return will be run asynchronously off the main thread,
 * so it's important to retrieve any objects from your section _outside_ the block
 * because by the time the block is run, the array may have changed.
 *
 * @param index The index of the item.
 * @return A block to be run concurrently to build the node for this item.
 * @see collectionNode:nodeBlockForItemAtIndexPath:
 */
- (ASCellNodeBlock)nodeBlockForItemAtIndex:(NSInteger)index;

@optional

/**
 * Asks the section controller whether it should batch fetch because the user is
 * near the end of the current data set.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the assumed return value is @c YES.
 */
- (BOOL)shouldBatchFetch;

/**
 * Asks the section controller to begin fetching more content (tail loading) because
 * the user is near the end of the current data set.
 *
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 */
- (void)beginBatchFetchWithContext:(ASBatchContext *)context;

/**
 * A method to provide the size range used for measuring the item
 * at the given index.
 *
 * @param index The index of the item.
 * @return A size range used for asynchronously measuring the node at this index.
 * @see collectionNode:constrainedSizeForItemAtIndexPath:
 */
- (ASSizeRange)sizeRangeForItemAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END

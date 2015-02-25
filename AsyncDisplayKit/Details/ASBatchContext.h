/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

/**
 * @abstract A context object to notify when batch fetches are finished or cancelled.
 */
@interface ASBatchContext : NSObject

/**
 * Retreive the state of the current batch process.
 *
 * @returns A boolean reflecting if the owner of the context object is fetching another batch.
 */
- (BOOL)isFetching;

/**
 * Let the context object know that a batch fetch was completed.
 *
 * @param didComplete A boolean that states whether or not the batch fetch completed.
 *
 * @discussion Only by passing YES will the owner of the context know to attempt another batch update when necessary.
 * For instance, when a table has reached the end of its data, a batch fetch will be attempted unless the context
 * object thinks that it is still fetching.
 */
- (void)completeBatchFetching:(BOOL)didComplete;

/**
 * Ask the context object if the batch fetching process was cancelled by the context owner.
 *
 * @discussion If an error occurs in the context owner, the batch fetching may become out of sync and need to be
 * cancelled. For best practices, pass the return value of -batchWasCancelled to -completeBatchFetch:.
 *
 * @returns A boolean reflecting if the context object owner had to cancel the batch process.
 */
- (BOOL)batchFetchingWasCancelled;

/**
 * Notify the context object that something has interupted the batch fetching process.
 *
 * @discussion Call this method only when something has corrupted the batch fetching process. Calling this method should
 * be left to the owner of the batch process unless there is a specific purpose.
 */
- (void)cancelBatchFetching;

/**
 * Notify the context object that fetching has started.
 *
 * @discussion Call this method only when you are beginning a fetch process. This should really only be called by the 
 * context object's owner. Calling this method should be paired with -completeBatchFetching:.
 */
- (void)beginBatchFetching;

@end

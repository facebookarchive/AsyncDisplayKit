/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASBatchContext.h"

typedef NS_ENUM(NSInteger, ASBatchContextState) {
  ASBatchContextStateFetching,
  ASBatchContextStateCancelled,
  ASBatchContextStateCompleted
};

@interface ASBatchContext ()
{
  ASBatchContextState _state;
}
@end

@implementation ASBatchContext

- (instancetype)init
{
  if (self = [super init]) {
    _state = ASBatchContextStateCompleted;
  }
  return self;
}

- (BOOL)isFetching
{
  return _state == ASBatchContextStateFetching;
}

- (BOOL)batchFetchingWasCancelled
{
  return _state == ASBatchContextStateCancelled;
}

- (void)completeBatchFetching:(BOOL)didComplete
{
  if (didComplete) {
    _state = ASBatchContextStateCompleted;
  }
}

- (void)beginBatchFetching
{
  _state = ASBatchContextStateFetching;
}

- (void)cancelBatchFetching
{
  _state = ASBatchContextStateCancelled;
}

@end

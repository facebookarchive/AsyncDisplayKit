//
//  ASBatchContext.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASBatchContext.h>

#import <AsyncDisplayKit/ASThread.h>

typedef NS_ENUM(NSInteger, ASBatchContextState) {
  ASBatchContextStateFetching,
  ASBatchContextStateCancelled,
  ASBatchContextStateCompleted
};

@interface ASBatchContext ()
{
  ASBatchContextState _state;
  ASDN::RecursiveMutex __instanceLock__;
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
  ASDN::MutexLocker l(__instanceLock__);
  return _state == ASBatchContextStateFetching;
}

- (BOOL)batchFetchingWasCancelled
{
  ASDN::MutexLocker l(__instanceLock__);
  return _state == ASBatchContextStateCancelled;
}

- (void)beginBatchFetching
{
  ASDN::MutexLocker l(__instanceLock__);
  _state = ASBatchContextStateFetching;
}

- (void)completeBatchFetching:(BOOL)didComplete
{
  if (didComplete) {
    ASDN::MutexLocker l(__instanceLock__);
    _state = ASBatchContextStateCompleted;
  }
}

- (void)cancelBatchFetching
{
  ASDN::MutexLocker l(__instanceLock__);
  _state = ASBatchContextStateCancelled;
}

@end

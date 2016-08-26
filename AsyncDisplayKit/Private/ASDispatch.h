//
//  ASDispatch.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Like dispatch_apply, but you can set the thread count. 0 means 2*active CPUs.
 *
 * Note: The actual number of threads may be lower than threadCount, if libdispatch
 * decides the system can't handle it. In reality this rarely happens.
 */
static void ASDispatchApply(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, void(^work)(size_t i)) {
  if (threadCount == 0) {
    threadCount = [NSProcessInfo processInfo].activeProcessorCount * 2;
  }
  dispatch_group_t group = dispatch_group_create();
  __block size_t trueI = 0;
  for (NSUInteger t = 0; t < threadCount; t++) {
    dispatch_group_async(group, queue, ^{
      size_t i;
      while ((i = __sync_fetch_and_add(&trueI, 1)) < iterationCount) {
        work(i);
      }
    });
  }
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
};

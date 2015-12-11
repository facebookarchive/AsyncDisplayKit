//
//  ASMainSerialQueue.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 12/11/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASMainSerialQueue.h"

#import "ASThread.h"

@interface ASMainSerialQueue ()
{
  ASDN::Mutex _serialQueueLock;
  NSMutableArray *_blocks;
}

@end

@implementation ASMainSerialQueue

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _blocks = [[NSMutableArray alloc] init];
  return self;
}

- (void)performBlockOnMainThread:(dispatch_block_t)block
{
  ASDN::MutexLocker l(_serialQueueLock);
  [_blocks addObject:block];
  ASDN::MutexUnlocker u(_serialQueueLock);
  [self runBlocks];
}

- (void)runBlocks
{
  dispatch_block_t mainThread = ^{
    do {
      ASDN::MutexLocker l(_serialQueueLock);
      dispatch_block_t block;
      if (_blocks.count > 0) {
        block = [_blocks objectAtIndex:0];
        [_blocks removeObjectAtIndex:0];
      } else {
        break;
      }
      ASDN::MutexUnlocker u(_serialQueueLock);
      block();
    } while (true);
  };
  
  if ([NSThread isMainThread]) {
    mainThread();
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      mainThread();
    });
  }
}

@end

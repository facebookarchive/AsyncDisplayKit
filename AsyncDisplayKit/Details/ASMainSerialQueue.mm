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
  _serialQueueLock.lock();
  [_blocks addObject:block];
  _serialQueueLock.unlock();
  [self runBlocks];
}

- (void)runBlocks
{
  dispatch_block_t mainThread = ^{
    do {
      _serialQueueLock.lock();
      dispatch_block_t block;
      if (_blocks.count > 0) {
        block = [_blocks objectAtIndex:0];
        [_blocks removeObjectAtIndex:0];
        _serialQueueLock.unlock();
      } else {
        _serialQueueLock.unlock();
        break;
      }
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

//
//  ASMainQueueTransaction.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/26/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASMainQueueTransaction.h"
#import "ASAssert.h"

NSString *ASThreadMainQueueBlocksKey = @"asdk_propertiesTransactions";

@implementation ASMainQueueTransaction

+ (void)transactWithBlock:(void (^)())body
{
  ASDisplayNodeAssertNotNil(body, @"ASMainQueueTransaction requires a body block.");

  NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
  NSMutableArray *mainQueueBlocks = threadDictionary[ASThreadMainQueueBlocksKey];

  // If we're already collecting main queue blocks, just run the body and return.
  if (mainQueueBlocks != nil) {
    body();
    return;
  }

  // Create a new batch of main queue blocks and store it in the thread dictionary.
  mainQueueBlocks = [NSMutableArray new];
  threadDictionary[ASThreadMainQueueBlocksKey] = mainQueueBlocks;

  // Run the body. Any blocks passed to to `performOnMainThread` during
  // this invocation will be appended to `mainQueueBlocks`.
  body();

  [threadDictionary removeObjectForKey:ASThreadMainQueueBlocksKey];

  // If we accumulated any blocks, run them all in one main queue block.
  if (mainQueueBlocks.count > 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      for (dispatch_block_t block in mainQueueBlocks) {
        block();
      }
    });
  }
}

+ (void)performOnMainThread:(void (^)())mainThreadWork
{
  if (NSThread.isMainThread) {
    mainThreadWork();
    return;
  }

  NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
  NSMutableArray *mainQueueBlocks = threadDictionary[ASThreadMainQueueBlocksKey];

  if (mainQueueBlocks == nil) {
    dispatch_async(dispatch_get_main_queue(), mainThreadWork);
  } else {
    [mainQueueBlocks addObject:mainThreadWork];
  }
}

@end

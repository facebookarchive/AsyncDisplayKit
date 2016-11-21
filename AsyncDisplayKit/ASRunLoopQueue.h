//
//  ASRunLoopQueue.h
//  AsyncDisplayKit
//
//  Created by Rahul Malik on 3/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASRunLoopQueue<ObjectType> : NSObject

/**
 * Create a new queue with the given run loop and handler.
 *
 * @param runloop The run loop that will drive this queue.
 * @param handlerBlock An optional block to be run for each enqueued object.
 *
 * @discussion You may pass @c nil for the handler if you simply want the objects to
 * be retained at enqueue time, and released during the run loop step. This is useful
 * for creating a "main deallocation queue", as @c ASDeallocQueue creates its own 
 * worker thread with its own run loop.
 */
- (instancetype)initWithRunLoop:(CFRunLoopRef)runloop
                     andHandler:(nullable void(^)(ObjectType dequeuedItem, BOOL isQueueDrained))handlerBlock;

- (void)enqueue:(ObjectType)object;

@property (nonatomic, assign) NSUInteger batchSize;           // Default == 1.
@property (nonatomic, assign) BOOL ensureExclusiveMembership; // Default == YES.  Set-like behavior.

@end

@interface ASDeallocQueue : NSObject

+ (instancetype)sharedDeallocationQueue;

- (void)releaseObjectInBackground:(id)object;

@end

NS_ASSUME_NONNULL_END

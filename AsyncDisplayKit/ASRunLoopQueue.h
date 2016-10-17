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

- (instancetype)initWithRunLoop:(CFRunLoopRef)runloop
                     andHandler:(void(^)(ObjectType dequeuedItem, BOOL isQueueDrained))handlerBlock;

- (void)enqueue:(ObjectType)object;

@property (nonatomic, assign) NSUInteger batchSize;           // Default == 1.
@property (nonatomic, assign) BOOL ensureExclusiveMembership; // Default == YES.  Set-like behavior.

@end

@interface ASDeallocQueue : NSObject

+ (instancetype)sharedDeallocationQueue;

- (void)releaseObjectInBackground:(id)object;

@end

NS_ASSUME_NONNULL_END

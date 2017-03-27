//
//  PINOperationGroup.h
//  PINQueue
//
//  Created by Garrett Moon on 10/8/16.
//  Copyright © 2016 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PINOperationTypes.h"
#import "PINOperationMacros.h"

@class PINOperationQueue;

NS_ASSUME_NONNULL_BEGIN

@protocol PINGroupOperationReference;

PINOP_SUBCLASSING_RESTRICTED
@interface PINOperationGroup : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)asyncOperationGroupWithQueue:(PINOperationQueue *)operationQueue;

- (nullable id <PINGroupOperationReference>)addOperation:(dispatch_block_t)operation;
- (nullable id <PINGroupOperationReference>)addOperation:(dispatch_block_t)operation withPriority:(PINOperationQueuePriority)priority;
- (void)start;
- (void)cancel;
- (void)setCompletion:(dispatch_block_t)completion;
- (void)waitUntilComplete;

@end

@protocol PINGroupOperationReference <NSObject>

@end

NS_ASSUME_NONNULL_END

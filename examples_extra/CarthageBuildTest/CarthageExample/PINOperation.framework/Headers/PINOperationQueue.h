//
//  PINOperationQueue.h
//  Pods
//
//  Created by Garrett Moon on 8/23/16.
//
//

#import <Foundation/Foundation.h>
#import "PINOperationTypes.h"
#import "PINOperationMacros.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^PINOperationBlock)(id _Nullable data);
typedef _Nullable id(^PINOperationDataCoalescingBlock)(id _Nullable existingData, id _Nullable newData);

@protocol PINOperationReference;

PINOP_SUBCLASSING_RESTRICTED
@interface PINOperationQueue : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithMaxConcurrentOperations:(NSUInteger)maxConcurrentOperations;
- (instancetype)initWithMaxConcurrentOperations:(NSUInteger)maxConcurrentOperations concurrentQueue:(dispatch_queue_t)concurrentQueue NS_DESIGNATED_INITIALIZER;
+ (instancetype)sharedOperationQueue;

- (id <PINOperationReference>)addOperation:(dispatch_block_t)operation;
- (id <PINOperationReference>)addOperation:(dispatch_block_t)operation withPriority:(PINOperationQueuePriority)priority;
- (id <PINOperationReference>)addOperation:(PINOperationBlock)operation
                              withPriority:(PINOperationQueuePriority)priority
                                identifier:(NSString *)identifier
                            coalescingData:(nullable id)coalescingData
                       dataCoalescingBlock:(nullable PINOperationDataCoalescingBlock)dataCoalescingBlock
                                completion:(nullable dispatch_block_t)completion;

@property (assign) NSUInteger maxConcurrentOperations;

/**
 * Marks the operation as cancelled
 */
- (BOOL)cancelOperation:(id <PINOperationReference>)operationReference;

/**
 * Cancels all queued operations
 */
- (void)cancelAllOperations;

/*
 * Blocks the current thread until all of the receiver’s queued and executing operations finish executing.
 *
 * @discussion When called, this method blocks the current thread and waits for the receiver’s current and queued
 * operations to finish executing. While the current thread is blocked, the receiver continues to launch already
 * queued operations and monitor those that are executing.
 *
 * @warning This should never be called from within an operation submitted to the PINOperationQueue as this will result
 * in a deadlock.
 */
- (void)waitUntilAllOperationsAreFinished;

- (void)setOperationPriority:(PINOperationQueuePriority)priority withReference:(id <PINOperationReference>)reference;

@end

@protocol PINOperationReference <NSObject>

@end

NS_ASSUME_NONNULL_END

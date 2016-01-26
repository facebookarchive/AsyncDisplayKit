/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASAsyncTransaction.h"
#import "_ASAsyncTransactionGroup.h"
#import "ASAssert.h"
#import "ASThread.h"
#import <list>
#import <map>

@interface ASDisplayNodeAsyncTransactionOperation : NSObject
- (id)initWithOperationCompletionBlock:(asyncdisplaykit_async_transaction_operation_completion_block_t)operationCompletionBlock;
@property (nonatomic, copy) asyncdisplaykit_async_transaction_operation_completion_block_t operationCompletionBlock;
@property (atomic, retain) id<NSObject> value; // set on bg queue by the operation block
@end

@implementation ASDisplayNodeAsyncTransactionOperation

- (id)initWithOperationCompletionBlock:(asyncdisplaykit_async_transaction_operation_completion_block_t)operationCompletionBlock
{
  if ((self = [super init])) {
    _operationCompletionBlock = [operationCompletionBlock copy];
  }
  return self;
}

- (void)dealloc
{
  ASDisplayNodeAssertNil(_operationCompletionBlock, @"Should have been called and released before -dealloc");
}

- (void)callAndReleaseCompletionBlock:(BOOL)canceled;
{
  if (_operationCompletionBlock) {
    _operationCompletionBlock(self.value, canceled);
    // Guarantee that _operationCompletionBlock is released on _callbackQueue:
    self.operationCompletionBlock = nil;
  }
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<ASDisplayNodeAsyncTransactionOperation: %p - value = %@", self, self.value];
}

@end

// Lightweight operation queue for _ASAsyncTransaction that limits number of spawned threads
class ASAsyncTransactionQueue
{
public:
  
  // Similar to dispatch_group_t
  class Group
  {
  public:
    // call when group is no longer needed; after last scheduled operation the group will delete itself
    virtual void release() = 0;
    
    // schedule block on given queue
    virtual void schedule(dispatch_queue_t queue, dispatch_block_t block) = 0;
    
    // dispatch block on given queue when all previously scheduled blocks finished executing
    virtual void notify(dispatch_queue_t queue, dispatch_block_t block) = 0;
    
    // used when manually executing blocks
    virtual void enter() = 0;
    virtual void leave() = 0;
    
    // wait until all scheduled blocks finished executing
    virtual void wait() = 0;
    
  protected:
    virtual ~Group() { }; // call release() instead
  };
  
  // Create new group
  Group *createGroup();
  
  static ASAsyncTransactionQueue &instance();
  
private:
  
  struct GroupNotify
  {
    dispatch_block_t _block;
    dispatch_queue_t _queue;
  };
  
  class GroupImpl : public Group
  {
  public:
    GroupImpl(ASAsyncTransactionQueue &queue)
      : _pendingOperations(0)
      , _releaseCalled(false)
      , _queue(queue)
    {
    }
    
    virtual void release();
    virtual void schedule(dispatch_queue_t queue, dispatch_block_t block);
    virtual void notify(dispatch_queue_t queue, dispatch_block_t block);
    virtual void enter();
    virtual void leave();
    virtual void wait();
    
    int _pendingOperations;
    std::list<GroupNotify> _notifyList;
    ASDN::Condition _condition;
    BOOL _releaseCalled;
    ASAsyncTransactionQueue &_queue;
  };
  
  struct Operation
  {
    dispatch_block_t _block;
    GroupImpl *_group;
  };
  
  struct DispatchEntry // entry for each
  {
    std::list<Operation> _operations;
    int _threadCount;
  };
  
  std::map<dispatch_queue_t, DispatchEntry> _entries;
  ASDN::Mutex _mutex;
};

ASAsyncTransactionQueue::Group* ASAsyncTransactionQueue::createGroup()
{
  Group *res = new GroupImpl(*this);
  return res;
}

void ASAsyncTransactionQueue::GroupImpl::release()
{
  ASDN::MutexLocker locker(_queue._mutex);
  
  if (_pendingOperations == 0)  {
    delete this;
  } else {
    _releaseCalled = true;
  }
}

void ASAsyncTransactionQueue::GroupImpl::schedule(dispatch_queue_t queue, dispatch_block_t block)
{
  ASAsyncTransactionQueue &q = _queue;
  ASDN::MutexLocker locker(q._mutex);
  
  DispatchEntry &entry = q._entries[queue];
  
  Operation operation;
  operation._block = block;
  operation._group = this;
  entry._operations.push_back(operation);
  
  ++_pendingOperations; // enter group
  
  NSUInteger maxThreads = [NSProcessInfo processInfo].activeProcessorCount;
  if (maxThreads < 2) { // it is reasonable to have at least two working threads, also
    maxThreads = 2;     // [_ASDisplayLayerTests testTransaction] requires at least two threads
  }

#if 0
  // Bit questionable - we can give main thread more CPU time during tracking;
  if (maxThreads > 1 && [[NSRunLoop mainRunLoop].currentMode isEqualToString:UITrackingRunLoopMode])
    --maxThreads;
#endif
  
  if (entry._threadCount < maxThreads) { // we need to spawn another thread

    ++entry._threadCount;
    
    dispatch_async(queue, ^{
      ASDN::MutexLocker lock(q._mutex);
      
      // go until there are no more pending operations
      while (!entry._operations.empty()) {
        Operation operation = entry._operations.front();
        entry._operations.pop_front();
        {
          ASDN::MutexUnlocker unlock(q._mutex);
          if (operation._block) {
            operation._block();
          }
          operation._group->leave();
          operation._block = 0; // the block must be freed while mutex is unlocked
        }
      }
      --entry._threadCount;
      
      if (entry._threadCount == 0) {
        NSCAssert(entry._operations.empty(), @"No working threads but operations are still scheduled"); // this shouldn't happen
        q._entries.erase(queue);
      }
    });
  }
}

void ASAsyncTransactionQueue::GroupImpl::notify(dispatch_queue_t queue, dispatch_block_t block)
{
  ASDN::MutexLocker locker(_queue._mutex);
  
  if (_pendingOperations == 0) {
    dispatch_async(queue, block);
  } else {
    GroupNotify notify;
    notify._block = block;
    notify._queue = queue;
    _notifyList.push_back(notify);
  }
}

void ASAsyncTransactionQueue::GroupImpl::enter()
{
  ASDN::MutexLocker locker(_queue._mutex);
  ++_pendingOperations;
}

void ASAsyncTransactionQueue::GroupImpl::leave()
{
  ASDN::MutexLocker locker(_queue._mutex);
  --_pendingOperations;
  
  if (_pendingOperations == 0) {
    std::list<GroupNotify> notifyList;
    _notifyList.swap(notifyList);
    
    for (GroupNotify & notify : notifyList) {
      dispatch_async(notify._queue, notify._block);
    }
    
    _condition.signal();
    
    // there was attempt to release the group before, but we still
    // had operations scheduled so now is good time
    if (_releaseCalled) {
      delete this;
    }
  }
}

void ASAsyncTransactionQueue::GroupImpl::wait()
{
  ASDN::MutexLocker locker(_queue._mutex);
  while (_pendingOperations > 0) {
    _condition.wait(_queue._mutex);
  }
}

ASAsyncTransactionQueue & ASAsyncTransactionQueue::instance()
{
  static ASAsyncTransactionQueue *instance = new ASAsyncTransactionQueue();
  return *instance;
}

@implementation _ASAsyncTransaction
{
  ASAsyncTransactionQueue::Group *_group;
  NSMutableArray *_operations;
}

#pragma mark -
#pragma mark Lifecycle

- (id)initWithCallbackQueue:(dispatch_queue_t)callbackQueue
            completionBlock:(void(^)(_ASAsyncTransaction *, BOOL))completionBlock
{
  if ((self = [self init])) {
    if (callbackQueue == NULL) {
      callbackQueue = dispatch_get_main_queue();
    }
    _callbackQueue = callbackQueue;
    _completionBlock = [completionBlock copy];

    _state = ASAsyncTransactionStateOpen;
  }
  return self;
}

- (void)dealloc
{
  // Uncommitted transactions break our guarantees about releasing completion blocks on callbackQueue.
  ASDisplayNodeAssert(_state != ASAsyncTransactionStateOpen, @"Uncommitted ASAsyncTransactions are not allowed");
  if (_group) {
    _group->release();
  }
}

#pragma mark -
#pragma mark Transaction Management

- (void)addAsyncOperationWithBlock:(asyncdisplaykit_async_transaction_async_operation_block_t)block
                             queue:(dispatch_queue_t)queue
                        completion:(asyncdisplaykit_async_transaction_operation_completion_block_t)completion
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_state == ASAsyncTransactionStateOpen, @"You can only add operations to open transactions");

  [self _ensureTransactionData];

  ASDisplayNodeAsyncTransactionOperation *operation = [[ASDisplayNodeAsyncTransactionOperation alloc] initWithOperationCompletionBlock:completion];
  [_operations addObject:operation];
  _group->schedule(queue, ^{
    @autoreleasepool {
      if (_state != ASAsyncTransactionStateCanceled) {
        _group->enter();
        block(^(id<NSObject> value){
          operation.value = value;
          _group->leave();
        });
      }
    }
  });
}

- (void)addOperationWithBlock:(asyncdisplaykit_async_transaction_operation_block_t)block
                        queue:(dispatch_queue_t)queue
                   completion:(asyncdisplaykit_async_transaction_operation_completion_block_t)completion
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_state == ASAsyncTransactionStateOpen, @"You can only add operations to open transactions");

  [self _ensureTransactionData];

  ASDisplayNodeAsyncTransactionOperation *operation = [[ASDisplayNodeAsyncTransactionOperation alloc] initWithOperationCompletionBlock:completion];
  [_operations addObject:operation];
  _group->schedule(queue, ^{
    @autoreleasepool {
      if (_state != ASAsyncTransactionStateCanceled) {
        operation.value = block();
      }
    }
  });
}

- (void)addCompletionBlock:(asyncdisplaykit_async_transaction_completion_block_t)completion
{
  __weak __typeof__(self) weakSelf = self;
  [self addOperationWithBlock:^(){return (id<NSObject>)nil;} queue:_callbackQueue completion:^(id<NSObject> value, BOOL canceled) {
    __typeof__(self) strongSelf = weakSelf;
    completion(strongSelf, canceled);
  }];
}

- (void)cancel
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_state != ASAsyncTransactionStateOpen, @"You can only cancel a committed or already-canceled transaction");
  _state = ASAsyncTransactionStateCanceled;
}

- (void)commit
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_state == ASAsyncTransactionStateOpen, @"You cannot double-commit a transaction");
  _state = ASAsyncTransactionStateCommitted;
  
  if ([_operations count] == 0) {
    // Fast path: if a transaction was opened, but no operations were added, execute completion block synchronously.
    if (_completionBlock) {
      _completionBlock(self, NO);
    }
  } else {
    ASDisplayNodeAssert(_group != NULL, @"If there are operations, dispatch group should have been created");
    
    _group->notify(_callbackQueue, ^{
      // _callbackQueue is the main queue in current practice (also asserted in -waitUntilComplete).
      // This code should be reviewed before taking on significantly different use cases.
      ASDisplayNodeAssertMainThread();
      [self completeTransaction];
    });
  }
}

- (void)completeTransaction
{
  if (_state != ASAsyncTransactionStateComplete) {
    BOOL isCanceled = (_state == ASAsyncTransactionStateCanceled);
    for (ASDisplayNodeAsyncTransactionOperation *operation in _operations) {
      [operation callAndReleaseCompletionBlock:isCanceled];
    }
    
    // Always set _state to Complete, even if we were cancelled, to block any extraneous
    // calls to this method that may have been scheduled for the next runloop
    // (e.g. if we needed to force one in this runloop with -waitUntilComplete, but another was already scheduled)
    _state = ASAsyncTransactionStateComplete;

    if (_completionBlock) {
      _completionBlock(self, isCanceled);
    }
  }
}

- (void)waitUntilComplete
{
  ASDisplayNodeAssertMainThread();
  if (_state != ASAsyncTransactionStateComplete) {
    if (_group) {
      ASDisplayNodeAssertTrue(_callbackQueue == dispatch_get_main_queue());
      _group->wait();
      
      // At this point, the asynchronous operation may have completed, but the runloop
      // observer has not committed the batch of transactions we belong to.  It's important to
      // commit ourselves via the group to avoid double-committing the transaction.
      // This is only necessary when forcing display work to complete before allowing the runloop
      // to continue, e.g. in the implementation of -[ASDisplayNode recursivelyEnsureDisplay].
      if (_state == ASAsyncTransactionStateOpen) {
        [_ASAsyncTransactionGroup commit];
        ASDisplayNodeAssert(_state != ASAsyncTransactionStateOpen, @"Transaction should not be open after committing group");
      }
      // If we needed to commit the group above, -completeTransaction may have already been run.
      // It is designed to accomodate this by checking _state to ensure it is not complete.
      [self completeTransaction];
    }
  }
}

#pragma mark -
#pragma mark Helper Methods

- (void)_ensureTransactionData
{
  // Lazily initialize _group and _operations to avoid overhead in the case where no operations are added to the transaction
  if (_group == NULL) {
    _group = ASAsyncTransactionQueue::instance().createGroup();
  }
  if (_operations == nil) {
    _operations = [[NSMutableArray alloc] init];
  }
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<_ASAsyncTransaction: %p - _state = %lu, _group = %p, _operations = %@>", self, (unsigned long)_state, _group, _operations];
}

@end

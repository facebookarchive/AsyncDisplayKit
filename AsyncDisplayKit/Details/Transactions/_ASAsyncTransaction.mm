//
//  _ASAsyncTransaction.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

// We need this import for UITrackingRunLoopMode
#import <UIKit/UIApplication.h>

#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASAsyncTransactionGroup.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASLog.h>
#import <AsyncDisplayKit/ASThread.h>
#import <list>
#import <map>
#import <mutex>
#import <stdatomic.h>

#define ASAsyncTransactionAssertMainThread() NSAssert(0 != pthread_main_np(), @"This method must be called on the main thread");

NSInteger const ASDefaultTransactionPriority = 0;

@interface ASAsyncTransactionOperation : NSObject
- (instancetype)initWithOperationCompletionBlock:(asyncdisplaykit_async_transaction_operation_completion_block_t)operationCompletionBlock;
@property (nonatomic, copy) asyncdisplaykit_async_transaction_operation_completion_block_t operationCompletionBlock;
@property (nonatomic, strong) id<NSObject> value; // set on bg queue by the operation block
@end

@implementation ASAsyncTransactionOperation

- (instancetype)initWithOperationCompletionBlock:(asyncdisplaykit_async_transaction_operation_completion_block_t)operationCompletionBlock
{
  if ((self = [super init])) {
    _operationCompletionBlock = operationCompletionBlock;
  }
  return self;
}

- (void)dealloc
{
  NSAssert(_operationCompletionBlock == nil, @"Should have been called and released before -dealloc");
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
  return [NSString stringWithFormat:@"<ASAsyncTransactionOperation: %p - value = %@", self, self.value];
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
    virtual void schedule(NSInteger priority, dispatch_queue_t queue, dispatch_block_t block) = 0;
    
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
    virtual void schedule(NSInteger priority, dispatch_queue_t queue, dispatch_block_t block);
    virtual void notify(dispatch_queue_t queue, dispatch_block_t block);
    virtual void enter();
    virtual void leave();
    virtual void wait();
    
    int _pendingOperations;
    std::list<GroupNotify> _notifyList;
    std::condition_variable _condition;
    BOOL _releaseCalled;
    ASAsyncTransactionQueue &_queue;
  };
  
  struct Operation
  {
    dispatch_block_t _block;
    GroupImpl *_group;
    NSInteger _priority;
  };
    
  struct DispatchEntry // entry for each dispatch queue
  {
    typedef std::list<Operation> OperationQueue;
    typedef std::list<OperationQueue::iterator> OperationIteratorList; // each item points to operation queue
    typedef std::map<NSInteger, OperationIteratorList> OperationPriorityMap; // sorted by priority

    OperationQueue _operationQueue;
    OperationPriorityMap _operationPriorityMap;
    int _threadCount;
      
    Operation popNextOperation(bool respectPriority);  // assumes locked mutex
    void pushOperation(Operation operation);           // assumes locked mutex
  };
  
  std::map<dispatch_queue_t, DispatchEntry> _entries;
  std::mutex _mutex;
};

ASAsyncTransactionQueue::Group* ASAsyncTransactionQueue::createGroup()
{
  Group *res = new GroupImpl(*this);
  return res;
}

void ASAsyncTransactionQueue::GroupImpl::release()
{
  std::lock_guard<std::mutex> l(_queue._mutex);
  
  if (_pendingOperations == 0)  {
    delete this;
  } else {
    _releaseCalled = YES;
  }
}

ASAsyncTransactionQueue::Operation ASAsyncTransactionQueue::DispatchEntry::popNextOperation(bool respectPriority)
{
  NSCAssert(!_operationQueue.empty() && !_operationPriorityMap.empty(), @"No scheduled operations available");

  OperationQueue::iterator queueIterator;
  OperationPriorityMap::iterator mapIterator;
  
  if (respectPriority) {
    mapIterator = --_operationPriorityMap.end();  // highest priority "bucket"
    queueIterator = *mapIterator->second.begin();
  } else {
    queueIterator = _operationQueue.begin();
    mapIterator = _operationPriorityMap.find(queueIterator->_priority);
  }
  
  // no matter what, first item in "bucket" must match item in queue
  NSCAssert(mapIterator->second.front() == queueIterator, @"Queue inconsistency");
  
  Operation res = *queueIterator;
  _operationQueue.erase(queueIterator);
  
  mapIterator->second.pop_front();
  if (mapIterator->second.empty()) {
    _operationPriorityMap.erase(mapIterator);
  }

  return res;
}

void ASAsyncTransactionQueue::DispatchEntry::pushOperation(ASAsyncTransactionQueue::Operation operation)
{
  _operationQueue.push_back(operation);

  OperationIteratorList &list = _operationPriorityMap[operation._priority];
  list.push_back(--_operationQueue.end());
}

void ASAsyncTransactionQueue::GroupImpl::schedule(NSInteger priority, dispatch_queue_t queue, dispatch_block_t block)
{
  ASAsyncTransactionQueue &q = _queue;
  std::lock_guard<std::mutex> l(q._mutex);
  
  DispatchEntry &entry = q._entries[queue];
  
  Operation operation;
  operation._block = block;
  operation._group = this;
  operation._priority = priority;
  entry.pushOperation(operation);
  
  ++_pendingOperations; // enter group
  
#if ASDISPLAYNODE_DELAY_DISPLAY
  NSUInteger maxThreads = 1;
#else 
  NSUInteger maxThreads = [NSProcessInfo processInfo].activeProcessorCount * 2;

  // Bit questionable maybe - we can give main thread more CPU time during tracking;
  if ([[NSRunLoop mainRunLoop].currentMode isEqualToString:UITrackingRunLoopMode])
    --maxThreads;
#endif
  
  if (entry._threadCount < maxThreads) { // we need to spawn another thread

    // first thread will take operations in queue order (regardless of priority), other threads will respect priority
    bool respectPriority = entry._threadCount > 0;
    ++entry._threadCount;
    
    dispatch_async(queue, ^{
      std::unique_lock<std::mutex> lock(q._mutex);
      
      // go until there are no more pending operations
      while (!entry._operationQueue.empty()) {
        Operation operation = entry.popNextOperation(respectPriority);
        lock.unlock();
        if (operation._block) {
          ASProfilingSignpostStart(3, operation._block);
          operation._block();
          ASProfilingSignpostEnd(3, operation._block);
        }
        operation._group->leave();
        operation._block = nil; // the block must be freed while mutex is unlocked
        lock.lock();
      }
      --entry._threadCount;
      
      if (entry._threadCount == 0) {
        NSCAssert(entry._operationQueue.empty() || entry._operationPriorityMap.empty(), @"No working threads but operations are still scheduled"); // this shouldn't happen
        q._entries.erase(queue);
      }
    });
  }
}

void ASAsyncTransactionQueue::GroupImpl::notify(dispatch_queue_t queue, dispatch_block_t block)
{
  std::lock_guard<std::mutex> l(_queue._mutex);

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
  std::lock_guard<std::mutex> l(_queue._mutex);
  ++_pendingOperations;
}

void ASAsyncTransactionQueue::GroupImpl::leave()
{
  std::lock_guard<std::mutex> l(_queue._mutex);
  --_pendingOperations;
  
  if (_pendingOperations == 0) {
    std::list<GroupNotify> notifyList;
    _notifyList.swap(notifyList);
    
    for (GroupNotify & notify : notifyList) {
      dispatch_async(notify._queue, notify._block);
    }
    
    _condition.notify_one();
    
    // there was attempt to release the group before, but we still
    // had operations scheduled so now is good time
    if (_releaseCalled) {
      delete this;
    }
  }
}

void ASAsyncTransactionQueue::GroupImpl::wait()
{
  std::unique_lock<std::mutex> lock(_queue._mutex);
  while (_pendingOperations > 0) {
    _condition.wait(lock);
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
  NSMutableArray<ASAsyncTransactionOperation *> *_operations;
  _Atomic(ASAsyncTransactionState) _state;
}

#pragma mark -
#pragma mark Lifecycle

- (instancetype)initWithCallbackQueue:(dispatch_queue_t)callbackQueue
                      completionBlock:(void(^)(_ASAsyncTransaction *, BOOL))completionBlock
{
  if ((self = [self init])) {
    if (callbackQueue == NULL) {
      callbackQueue = dispatch_get_main_queue();
    }
    _callbackQueue = callbackQueue;
    _completionBlock = completionBlock;

    _state = ATOMIC_VAR_INIT(ASAsyncTransactionStateOpen);
  }
  return self;
}

- (void)dealloc
{
  // Uncommitted transactions break our guarantees about releasing completion blocks on callbackQueue.
  NSAssert(self.state != ASAsyncTransactionStateOpen, @"Uncommitted ASAsyncTransactions are not allowed");
  if (_group) {
    _group->release();
  }
}

#pragma mark - Properties

- (ASAsyncTransactionState)state
{
  return atomic_load(&_state);
}

- (void)setState:(ASAsyncTransactionState)state
{
  atomic_store(&_state, state);
}

#pragma mark - Transaction Management

- (void)addAsyncOperationWithBlock:(asyncdisplaykit_async_transaction_async_operation_block_t)block
                             queue:(dispatch_queue_t)queue
                        completion:(asyncdisplaykit_async_transaction_operation_completion_block_t)completion
{
  [self addAsyncOperationWithBlock:block
                          priority:ASDefaultTransactionPriority
                             queue:queue
                        completion:completion];
}

- (void)addAsyncOperationWithBlock:(asyncdisplaykit_async_transaction_async_operation_block_t)block
                          priority:(NSInteger)priority
                             queue:(dispatch_queue_t)queue
                        completion:(asyncdisplaykit_async_transaction_operation_completion_block_t)completion
{
  ASAsyncTransactionAssertMainThread();
  NSAssert(self.state == ASAsyncTransactionStateOpen, @"You can only add operations to open transactions");

  [self _ensureTransactionData];

  ASAsyncTransactionOperation *operation = [[ASAsyncTransactionOperation alloc] initWithOperationCompletionBlock:completion];
  [_operations addObject:operation];
  _group->schedule(priority, queue, ^{
    @autoreleasepool {
      if (self.state != ASAsyncTransactionStateCanceled) {
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
    [self addOperationWithBlock:block
                       priority:ASDefaultTransactionPriority
                          queue:queue
                     completion:completion];
}

- (void)addOperationWithBlock:(asyncdisplaykit_async_transaction_operation_block_t)block
                     priority:(NSInteger)priority
                        queue:(dispatch_queue_t)queue
                   completion:(asyncdisplaykit_async_transaction_operation_completion_block_t)completion
{
  ASAsyncTransactionAssertMainThread();
  NSAssert(self.state == ASAsyncTransactionStateOpen, @"You can only add operations to open transactions");

  [self _ensureTransactionData];

  ASAsyncTransactionOperation *operation = [[ASAsyncTransactionOperation alloc] initWithOperationCompletionBlock:completion];
  [_operations addObject:operation];
  _group->schedule(priority, queue, ^{
    @autoreleasepool {
      if (self.state != ASAsyncTransactionStateCanceled) {
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
  ASAsyncTransactionAssertMainThread();
  NSAssert(self.state != ASAsyncTransactionStateOpen, @"You can only cancel a committed or already-canceled transaction");
  self.state = ASAsyncTransactionStateCanceled;
}

- (void)commit
{
  ASAsyncTransactionAssertMainThread();
  NSAssert(self.state == ASAsyncTransactionStateOpen, @"You cannot double-commit a transaction");
  self.state = ASAsyncTransactionStateCommitted;
  
  if ([_operations count] == 0) {
    // Fast path: if a transaction was opened, but no operations were added, execute completion block synchronously.
    if (_completionBlock) {
      _completionBlock(self, NO);
    }
  } else {
    NSAssert(_group != NULL, @"If there are operations, dispatch group should have been created");
    
    _group->notify(_callbackQueue, ^{
      // _callbackQueue is the main queue in current practice (also asserted in -waitUntilComplete).
      // This code should be reviewed before taking on significantly different use cases.
      ASAsyncTransactionAssertMainThread();
      [self completeTransaction];
    });
  }
}

- (void)completeTransaction
{
  ASAsyncTransactionState state = self.state;
  if (state != ASAsyncTransactionStateComplete) {
    BOOL isCanceled = (state == ASAsyncTransactionStateCanceled);
    for (ASAsyncTransactionOperation *operation in _operations) {
      [operation callAndReleaseCompletionBlock:isCanceled];
    }
    
    // Always set state to Complete, even if we were cancelled, to block any extraneous
    // calls to this method that may have been scheduled for the next runloop
    // (e.g. if we needed to force one in this runloop with -waitUntilComplete, but another was already scheduled)
    self.state = ASAsyncTransactionStateComplete;

    if (_completionBlock) {
      _completionBlock(self, isCanceled);
    }
  }
}

- (void)waitUntilComplete
{
  ASAsyncTransactionAssertMainThread();
  if (self.state != ASAsyncTransactionStateComplete) {
    if (_group) {
      NSAssert(_callbackQueue == dispatch_get_main_queue(), nil);
      _group->wait();
      
      // At this point, the asynchronous operation may have completed, but the runloop
      // observer has not committed the batch of transactions we belong to.  It's important to
      // commit ourselves via the group to avoid double-committing the transaction.
      // This is only necessary when forcing display work to complete before allowing the runloop
      // to continue, e.g. in the implementation of -[ASDisplayNode recursivelyEnsureDisplay].
      if (self.state == ASAsyncTransactionStateOpen) {
        [_ASAsyncTransactionGroup commit];
        NSAssert(self.state != ASAsyncTransactionStateOpen, @"Transaction should not be open after committing group");
      }
      // If we needed to commit the group above, -completeTransaction may have already been run.
      // It is designed to accommodate this by checking _state to ensure it is not complete.
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
  return [NSString stringWithFormat:@"<_ASAsyncTransaction: %p - _state = %lu, _group = %p, _operations = %@>", self, (unsigned long)self.state, _group, _operations];
}

@end

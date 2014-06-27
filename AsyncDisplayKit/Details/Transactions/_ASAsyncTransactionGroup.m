 /* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASAssert.h"

#import "_ASAsyncTransaction.h"
#import "_ASAsyncTransactionGroup.h"
#import "_ASAsyncTransactionContainer+Private.h"

static void _transactionGroupRunLoopObserverCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info);

@interface _ASAsyncTransactionGroup ()
+ (void)registerTransactionGroupAsMainRunloopObserver:(_ASAsyncTransactionGroup *)transactionGroup;
- (void)commit;
@end

@implementation _ASAsyncTransactionGroup {
  NSHashTable *_containerLayers;
}

+ (_ASAsyncTransactionGroup *)mainTransactionGroup
{
  ASDisplayNodeAssertMainThread();
  static _ASAsyncTransactionGroup *mainTransactionGroup;

  if (mainTransactionGroup == nil) {
    mainTransactionGroup = [[_ASAsyncTransactionGroup alloc] init];
    [self registerTransactionGroupAsMainRunloopObserver:mainTransactionGroup];
  }
  return mainTransactionGroup;
}

+ (void)registerTransactionGroupAsMainRunloopObserver:(_ASAsyncTransactionGroup *)transactionGroup
{
  ASDisplayNodeAssertMainThread();
  static CFRunLoopObserverRef observer;
  ASDisplayNodeAssert(observer == NULL, @"A _ASAsyncTransactionGroup should not be registered on the main runloop twice");
  // defer the commit of the transaction so we can add more during the current runloop iteration
  CFRunLoopRef runLoop = CFRunLoopGetCurrent();
  CFOptionFlags activities = (kCFRunLoopBeforeWaiting | // before the run loop starts sleeping
                              kCFRunLoopExit);          // before exiting a runloop run
  CFRunLoopObserverContext context = {
    0,           // version
    (__bridge void *)transactionGroup,  // info
    &CFRetain,   // retain
    &CFRelease,  // release
    NULL         // copyDescription
  };

  observer = CFRunLoopObserverCreate(NULL,        // allocator
                                     activities,  // activities
                                     YES,         // repeats
                                     INT_MAX,     // order after CA transaction commits
                                     &_transactionGroupRunLoopObserverCallback,  // callback
                                     &context);   // context
  CFRunLoopAddObserver(runLoop, observer, kCFRunLoopCommonModes);
  CFRelease(observer);
}

- (id)init
{
  if ((self = [super init])) {
    _containerLayers = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
  }
  return self;
}

- (void)addTransactionContainer:(CALayer *)containerLayer
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(containerLayer != nil, @"No container");
  [_containerLayers addObject:containerLayer];
}

- (void)commit
{
  ASDisplayNodeAssertMainThread();

  if ([_containerLayers count]) {
    NSHashTable *containerLayersToCommit = [_containerLayers copy];
    [_containerLayers removeAllObjects];

    for (CALayer *containerLayer in containerLayersToCommit) {
      // Note that the act of committing a transaction may open a new transaction,
      // so we must nil out the transaction we're committing first.
      _ASAsyncTransaction *transaction = containerLayer.asyncdisplaykit_currentAsyncLayerTransaction;
      containerLayer.asyncdisplaykit_currentAsyncLayerTransaction = nil;
      [transaction commit];
    }
  }
}

@end

static void _transactionGroupRunLoopObserverCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
  ASDisplayNodeCAssertMainThread();
  _ASAsyncTransactionGroup *group = (__bridge _ASAsyncTransactionGroup *)info;
  [group commit];
}

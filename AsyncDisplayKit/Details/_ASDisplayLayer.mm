/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASDisplayLayer.h"

#import <objc/runtime.h>

#import "_ASAsyncTransactionContainer.h"
#import "ASAssert.h"
#import "ASDisplayNode.h"
#import "ASDisplayNodeInternal.h"

@implementation _ASDisplayLayer
{
  ASDN::Mutex _asyncDelegateLock;
  // We can take this lock when we're setting displaySuspended and in setNeedsDisplay, so to not deadlock, this is recursive
  ASDN::RecursiveMutex _displaySuspendedLock;
  BOOL _displaySuspended;

  id<_ASDisplayLayerDelegate> __weak _asyncDelegate;
}

@dynamic displaysAsynchronously;

#pragma mark -
#pragma mark Lifecycle

- (id)init
{
  if ((self = [super init])) {
    _displaySentinel = [[ASSentinel alloc] init];

    self.opaque = YES;

#if DEBUG
    // This is too expensive to do in production on all layers.
    self.name = [NSString stringWithFormat:@"%@ (%p)", NSStringFromClass([self class]), self];
#endif
  }
  return self;
}

#pragma mark -
#pragma mark Properties

- (id<_ASDisplayLayerDelegate>)asyncDelegate
{
  ASDN::MutexLocker l(_asyncDelegateLock);
  return _asyncDelegate;
}

- (void)setAsyncDelegate:(id<_ASDisplayLayerDelegate>)asyncDelegate
{
  ASDisplayNodeAssert(!asyncDelegate || [asyncDelegate isKindOfClass:[ASDisplayNode class]], @"_ASDisplayLayer is inherently coupled to ASDisplayNode and cannot be used with another asyncDelegate.  Please rethink what you are trying to do.");
  ASDN::MutexLocker l(_asyncDelegateLock);
  _asyncDelegate = asyncDelegate;
}

- (void)setContents:(id)contents
{
  ASDisplayNodeAssertMainThread();
  [super setContents:contents];
}

- (BOOL)isDisplaySuspended
{
  ASDN::MutexLocker l(_displaySuspendedLock);
  return _displaySuspended;
}

- (void)setDisplaySuspended:(BOOL)displaySuspended
{
  ASDN::MutexLocker l(_displaySuspendedLock);
  if (_displaySuspended != displaySuspended) {
    _displaySuspended = displaySuspended;
    if (!displaySuspended) {
      // If resuming display, trigger a display now.
      [self setNeedsDisplay];
    } else {
      // If suspending display, cancel any current async display so that we don't have contents set on us when it's finished.
      [self cancelAsyncDisplay];
    }
  }
}

- (void)layoutSublayers
{
  [super layoutSublayers];

  ASDisplayNode *node = self.asyncdisplaykit_node;
  if (ASDisplayNodeThreadIsMain()) {
    [node __layout];
  } else {
    ASDisplayNodeFailAssert(@"not reached assertion");
    dispatch_async(dispatch_get_main_queue(), ^ {
      [node __layout];
    });
  }
}

- (void)setNeedsLayout
{
  ASDisplayNodeAssertMainThread();
  [super setNeedsLayout];
}

- (void)setNeedsDisplay
{
  ASDisplayNodeAssertMainThread();

  ASDN::MutexLocker l(_displaySuspendedLock);
  [self cancelAsyncDisplay];

  // Short circuit if display is suspended. When resumed, we will setNeedsDisplay at that time.
  if (!_displaySuspended) {
    [super setNeedsDisplay];
  }
}

#pragma mark -

+ (dispatch_queue_t)displayQueue
{
  static dispatch_queue_t displayQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    displayQueue = dispatch_queue_create("org.AsyncDisplayKit.ASDisplayLayer.displayQueue", DISPATCH_QUEUE_CONCURRENT);
    // we use the highpri queue to prioritize UI rendering over other async operations
    dispatch_set_target_queue(displayQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  });

  return displayQueue;
}

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"displaysAsynchronously"]) {
    return @YES;
  } else {
    return [super defaultValueForKey:key];
  }
}

#pragma mark -
#pragma mark Display

- (void)displayImmediately
{
  // REVIEW: Should this respect isDisplaySuspended?  If so, we'd probably want to synchronously display when
  // setDisplaySuspended:No is called, rather than just scheduling.  The thread affinity for the displayImmediately
  // call will be tricky if we need to support this, though.  It probably should just execute if displayImmediately is
  // called directly.  The caller should be responsible for not calling displayImmediately if it wants to obey the
  // suspended state.

  ASDisplayNodeAssertMainThread();
  [self display:NO];
}

- (void)_hackResetNeedsDisplay
{
  ASDisplayNodeAssertMainThread();
  // Don't listen to our subclasses crazy ideas about setContents by going through super
  super.contents = super.contents;
}

- (void)display
{
  [self _hackResetNeedsDisplay];

  ASDisplayNodeAssertMainThread();
  if (self.isDisplaySuspended) {
    return;
  }

  [self display:self.displaysAsynchronously];
}

- (void)display:(BOOL)asynchronously
{
  [self _performBlockWithAsyncDelegate:^(id<_ASDisplayLayerDelegate> asyncDelegate) {
    [asyncDelegate displayAsyncLayer:self asynchronously:asynchronously];
  }];
}

- (void)cancelAsyncDisplay
{
  ASDisplayNodeAssertMainThread();
  [_displaySentinel increment];
  [self _performBlockWithAsyncDelegate:^(id<_ASDisplayLayerDelegate> asyncDelegate) {
    [asyncDelegate cancelDisplayAsyncLayer:self];
  }];
}

- (NSString *)description
{
  // The standard UIView description is useless for debugging because all ASDisplayNode subclasses have _ASDisplayView-type views.
  // This allows us to at least see the name of the node subclass and get its pointer directly from [[UIWindow keyWindow] recursiveDescription].
  return [NSString stringWithFormat:@"<%@, layer = %@>", self.asyncdisplaykit_node, [super description]];
}

#pragma mark -
#pragma mark Helper Methods

- (void)_performBlockWithAsyncDelegate:(void(^)(id<_ASDisplayLayerDelegate> asyncDelegate))block
{
  id<_ASDisplayLayerDelegate> __attribute__((objc_precise_lifetime)) strongAsyncDelegate;
  {
    ASDN::MutexLocker l(_asyncDelegateLock);
    strongAsyncDelegate = _asyncDelegate;
  }
  block(strongAsyncDelegate);
}

@end

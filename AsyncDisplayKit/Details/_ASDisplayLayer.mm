//
//  _ASDisplayLayer.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "_ASDisplayLayer.h"

#import <objc/runtime.h>

#import "_ASAsyncTransactionContainer.h"
#import "ASAssert.h"
#import "ASDisplayNode.h"
#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+FrameworkPrivate.h"

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

- (instancetype)init
{
  if ((self = [super init])) {
    _displaySentinel = [[ASSentinel alloc] init];

    self.opaque = YES;
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

- (void)setBounds:(CGRect)bounds
{
  [super setBounds:bounds];
  self.asyncdisplaykit_node.threadSafeBounds = bounds;
}

#if DEBUG // These override is strictly to help detect application-level threading errors.  Avoid method overhead in release.
- (void)setContents:(id)contents
{
  ASDisplayNodeAssertMainThread();
  [super setContents:contents];
}

- (void)setNeedsLayout
{
  ASDisplayNodeAssertMainThread();
  [super setNeedsLayout];
}
#endif

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

- (void)setNeedsDisplay
{
  ASDisplayNodeAssertMainThread();

  _displaySuspendedLock.lock();
  
  // FIXME: Reconsider whether we should cancel a display in progress.
  // We should definitely cancel a display that is scheduled, but unstarted display.
  [self cancelAsyncDisplay];

  // Short circuit if display is suspended. When resumed, we will setNeedsDisplay at that time.
  if (!_displaySuspended) {
    [super setNeedsDisplay];
  }
  _displaySuspendedLock.unlock();
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
  // This method is a low-level bypass that avoids touching CA, including any reset of the
  // needsDisplay flag, until the .contents property is set with the result.
  // It is designed to be able to block the thread of any caller and fully execute the display.

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
  id<_ASDisplayLayerDelegate> __attribute__((objc_precise_lifetime)) strongAsyncDelegate;
  {
    _asyncDelegateLock.lock();
    strongAsyncDelegate = _asyncDelegate;
    _asyncDelegateLock.unlock();
  }
  
  [strongAsyncDelegate displayAsyncLayer:self asynchronously:asynchronously];
}

- (void)cancelAsyncDisplay
{
  ASDisplayNodeAssertMainThread();
  [_displaySentinel increment];

  id<_ASDisplayLayerDelegate> __attribute__((objc_precise_lifetime)) strongAsyncDelegate;
  {
    _asyncDelegateLock.lock();
    strongAsyncDelegate = _asyncDelegate;
    _asyncDelegateLock.unlock();
  }

  [strongAsyncDelegate cancelDisplayAsyncLayer:self];
}

- (NSString *)description
{
  // The standard UIView description is useless for debugging because all ASDisplayNode subclasses have _ASDisplayView-type views.
  // This allows us to at least see the name of the node subclass and get its pointer directly from [[UIWindow keyWindow] recursiveDescription].
  return [NSString stringWithFormat:@"<%@, layer = %@>", self.asyncdisplaykit_node, [super description]];
}

@end

//
//  _ASDisplayLayer.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASDisplayLayer.h>

#import <objc/runtime.h>

#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@implementation _ASDisplayLayer
{
  ASDN::Mutex _asyncDelegateLock;
  // We can take this lock when we're setting displaySuspended and in setNeedsDisplay, so to not deadlock, this is recursive
  ASDN::RecursiveMutex _displaySuspendedLock;
  BOOL _displaySuspended;
  BOOL _attemptedDisplayWhileZeroSized;

  struct {
    BOOL delegateDidChangeBounds:1;
  } _delegateFlags;

  id<_ASDisplayLayerDelegate> __weak _asyncDelegate;
}

@dynamic displaysAsynchronously;

#pragma mark -
#pragma mark Lifecycle

- (instancetype)init
{
  if ((self = [super init])) {

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

- (void)setDelegate:(id)delegate
{
  [super setDelegate:delegate];
  _delegateFlags.delegateDidChangeBounds = [delegate respondsToSelector:@selector(layer:didChangeBoundsWithOldValue:newValue:)];
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
  if (_delegateFlags.delegateDidChangeBounds) {
    CGRect oldBounds = self.bounds;
    [super setBounds:bounds];
    self.asyncdisplaykit_node.threadSafeBounds = bounds;
    [(id<ASCALayerExtendedDelegate>)self.delegate layer:self didChangeBoundsWithOldValue:oldBounds newValue:bounds];
    
  } else {
    [super setBounds:bounds];
    self.asyncdisplaykit_node.threadSafeBounds = bounds;
  }

  if (_attemptedDisplayWhileZeroSized && CGRectIsEmpty(bounds) == NO && self.needsDisplayOnBoundsChange == NO) {
    _attemptedDisplayWhileZeroSized = NO;
    [self setNeedsDisplay];
  }
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
  ASDisplayNodeAssertMainThread();
  [super layoutSublayers];

  [self.asyncdisplaykit_node __layout];
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
  ASDisplayNodeAssertMainThread();
  [self _hackResetNeedsDisplay];

  if (self.isDisplaySuspended) {
    return;
  }

  [self display:self.displaysAsynchronously];
}

- (void)display:(BOOL)asynchronously
{
  if (CGRectIsEmpty(self.bounds)) {
    _attemptedDisplayWhileZeroSized = YES;
  }

  id<_ASDisplayLayerDelegate> NS_VALID_UNTIL_END_OF_SCOPE strongAsyncDelegate;
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

  id<_ASDisplayLayerDelegate> NS_VALID_UNTIL_END_OF_SCOPE strongAsyncDelegate;
  {
    _asyncDelegateLock.lock();
    strongAsyncDelegate = _asyncDelegate;
    _asyncDelegateLock.unlock();
  }

  [strongAsyncDelegate cancelDisplayAsyncLayer:self];
}

// e.g. <MYTextNodeLayer: 0xFFFFFF; node = <MYTextNode: 0xFFFFFFE; name = "Username node for user 179">>
- (NSString *)description
{
  NSMutableString *description = [[super description] mutableCopy];
  ASDisplayNode *node = self.asyncdisplaykit_node;
  if (node != nil) {
    NSString *classString = [NSString stringWithFormat:@"%@-", [node class]];
    [description replaceOccurrencesOfString:@"_ASDisplay" withString:classString options:kNilOptions range:NSMakeRange(0, description.length)];
    NSUInteger insertionIndex = [description rangeOfString:@">"].location;
    if (insertionIndex != NSNotFound) {
      NSString *nodeString = [NSString stringWithFormat:@"; node = %@", node];
      [description insertString:nodeString atIndex:insertionIndex];
    }
  }
  return description;
}

@end

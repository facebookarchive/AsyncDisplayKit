//
//  ASDisplayLayerTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <objc/runtime.h>

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import <XCTest/XCTest.h>

#import "_ASDisplayLayer.h"
#import "_ASAsyncTransactionContainer.h"
#import "ASDisplayNode.h"
#import "ASDisplayNodeTestsHelper.h"

static UIImage *bogusImage() {
  static UIImage *bogusImage = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{

    UIGraphicsBeginImageContext(CGSizeMake(10, 10));

    bogusImage = [UIGraphicsGetImageFromCurrentImageContext() retain];

    UIGraphicsEndImageContext();

  });

  return bogusImage;
}

@interface _ASDisplayLayerTestContainerLayer : CALayer
@property (nonatomic, assign, readonly) NSUInteger didCompleteTransactionCount;
@end

@implementation _ASDisplayLayerTestContainerLayer

- (void)asyncdisplaykit_asyncTransactionContainerDidCompleteTransaction:(_ASAsyncTransaction *)transaction
{
  _didCompleteTransactionCount++;
}

@end


@interface ASDisplayNode (HackForTests)
- (id)initWithViewClass:(Class)viewClass;
- (id)initWithLayerClass:(Class)layerClass;
@end


@interface _ASDisplayLayerTestLayer : _ASDisplayLayer
{
  BOOL _isInCancelAsyncDisplay;
  BOOL _isInDisplay;
}
@property (nonatomic, assign, readonly) NSUInteger displayCount;
@property (nonatomic, assign, readonly) NSUInteger drawInContextCount;
@property (nonatomic, assign, readonly) NSUInteger setContentsAsyncCount;
@property (nonatomic, assign, readonly) NSUInteger setContentsSyncCount;
@property (nonatomic, copy, readonly) NSString *setContentsCounts;
- (BOOL)checkSetContentsCountsWithSyncCount:(NSUInteger)syncCount asyncCount:(NSUInteger)asyncCount;
@end

@implementation _ASDisplayLayerTestLayer

- (NSString *)setContentsCounts
{
  return [NSString stringWithFormat:@"syncCount:%tu, asyncCount:%tu", _setContentsSyncCount, _setContentsAsyncCount];
}

- (BOOL)checkSetContentsCountsWithSyncCount:(NSUInteger)syncCount asyncCount:(NSUInteger)asyncCount
{
  return ((syncCount == _setContentsSyncCount) &&
          (asyncCount == _setContentsAsyncCount));
}

- (void)setContents:(id)contents
{
  [super setContents:contents];

  if (self.displaysAsynchronously) {
    if (_isInDisplay) {
      [[NSException exceptionWithName:NSInvalidArgumentException
                               reason:@"There is no placeholder logic in _ASDisplayLayer, unknown caller for setContents:"
                             userInfo:nil] raise];
    } else if (!_isInCancelAsyncDisplay) {
      _setContentsAsyncCount++;
    }
  } else {
    _setContentsSyncCount++;
  }
}

- (void)display
{
  _isInDisplay = YES;
  [super display];
  _isInDisplay = NO;
  _displayCount++;
}

- (void)cancelAsyncDisplay
{
  _isInCancelAsyncDisplay = YES;
  [super cancelAsyncDisplay];
  _isInCancelAsyncDisplay = NO;
}

// This should never get called. This just records if it is.
- (void)drawInContext:(CGContextRef)context
{
  [super drawInContext:context];
  _drawInContextCount++;
}

@end

typedef NS_ENUM(NSUInteger, _ASDisplayLayerTestDelegateMode)
{
  _ASDisplayLayerTestDelegateModeNone                 = 0,
  _ASDisplayLayerTestDelegateModeDrawParameters       = 1 << 0,
  _ASDisplayLayerTestDelegateModeWillDisplay          = 1 << 1,
  _ASDisplayLayerTestDelegateModeDidDisplay           = 1 << 2,
};

typedef NS_ENUM(NSUInteger, _ASDisplayLayerTestDelegateClassModes) {
  _ASDisplayLayerTestDelegateClassModeNone                 = 0,
  _ASDisplayLayerTestDelegateClassModeDisplay              = 1 << 0,
  _ASDisplayLayerTestDelegateClassModeDrawInContext        = 1 << 1,
};

@interface _ASDisplayLayerTestDelegate : ASDisplayNode <_ASDisplayLayerDelegate>

@property (nonatomic, assign) NSUInteger didDisplayCount;
@property (nonatomic, assign) NSUInteger drawParametersCount;
@property (nonatomic, assign) NSUInteger willDisplayCount;

// for _ASDisplayLayerTestDelegateModeClassDisplay
@property (nonatomic, assign) NSUInteger displayCount;
@property (nonatomic, copy) UIImage *(^displayLayerBlock)();

// for _ASDisplayLayerTestDelegateModeClassDrawInContext
@property (nonatomic, assign) NSUInteger drawRectCount;

@end

@implementation _ASDisplayLayerTestDelegate {
  _ASDisplayLayerTestDelegateMode _modes;
}

static _ASDisplayLayerTestDelegateClassModes _class_modes;

+ (void)setClassModes:(_ASDisplayLayerTestDelegateClassModes)classModes
{
  _class_modes = classModes;
}

- (id)initWithModes:(_ASDisplayLayerTestDelegateMode)modes
{
  _modes = modes;

  if (!(self = [super initWithLayerClass:[_ASDisplayLayerTestLayer class]]))
    return nil;

  return self;
}

- (void)didDisplayAsyncLayer:(_ASDisplayLayer *)layer
{
  _didDisplayCount++;
}

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  _drawParametersCount++;
  return self;
}

- (void)willDisplayAsyncLayer:(_ASDisplayLayer *)layer
{
  _willDisplayCount++;
}

- (BOOL)respondsToSelector:(SEL)selector
{
  if (sel_isEqual(selector, @selector(didDisplayAsyncLayer:))) {
    return (_modes & _ASDisplayLayerTestDelegateModeDidDisplay);
  } else if (sel_isEqual(selector, @selector(drawParametersForAsyncLayer:))) {
    return (_modes & _ASDisplayLayerTestDelegateModeDrawParameters);
  } else if (sel_isEqual(selector, @selector(willDisplayAsyncLayer:))) {
    return (_modes & _ASDisplayLayerTestDelegateModeWillDisplay);
  } else {
    return [super respondsToSelector:selector];
  }
}

+ (BOOL)respondsToSelector:(SEL)selector
{
  if (sel_isEqual(selector, @selector(displayWithParameters:isCancelled:))) {
    return _class_modes & _ASDisplayLayerTestDelegateClassModeDisplay;
  } else if (sel_isEqual(selector, @selector(drawRect:withParameters:isCancelled:isRasterizing:))) {
    return _class_modes & _ASDisplayLayerTestDelegateClassModeDrawInContext;
  } else {
    return [super respondsToSelector:selector];
  }
}

// DANGER: Don't use the delegate as the parameters in real code; this is not thread-safe and just for accounting in unit tests!
+ (UIImage *)displayWithParameters:(_ASDisplayLayerTestDelegate *)delegate isCancelled:(asdisplaynode_iscancelled_block_t)sentinelBlock
{
  UIImage *contents = bogusImage();
  if (delegate->_displayLayerBlock != NULL) {
    contents = delegate->_displayLayerBlock();
  }
  delegate->_displayCount++;
  return contents;
}

// DANGER: Don't use the delegate as the parameters in real code; this is not thread-safe and just for accounting in unit tests!
+ (void)drawRect:(CGRect)bounds withParameters:(_ASDisplayLayerTestDelegate *)delegate isCancelled:(asdisplaynode_iscancelled_block_t)sentinelBlock isRasterizing:(BOOL)isRasterizing
{
  __atomic_add_fetch(&delegate->_drawRectCount, 1, __ATOMIC_SEQ_CST);
}

- (NSUInteger)drawRectCount
{
  return(__atomic_load_n(&_drawRectCount, __ATOMIC_SEQ_CST));
}

- (void)dealloc
{
  [_displayLayerBlock release];
  [super dealloc];
}

@end

@interface _ASDisplayLayerTests : XCTestCase
@end

@implementation _ASDisplayLayerTests

- (void)setUp {
  [super setUp];
  // Force bogusImage() to create+cache its image. This impacts any time-sensitive tests which call the method from
  // within the timed portion of the test. It seems that, in rare cases, this image creation can take a bit too long,
  // causing a test failure.
  bogusImage();
}

// since we're not running in an application, we need to force this display on layer the hierarchy
- (void)displayLayerRecursively:(CALayer *)layer
{
  if (layer.needsDisplay) {
    [layer displayIfNeeded];
  }
  for (CALayer *sublayer in layer.sublayers) {
    [self displayLayerRecursively:sublayer];
  }
}

- (void)waitForDisplayQueue
{
  // make sure we don't lock up the tests indefinitely; fail after 1 sec by using an async barrier
  __block BOOL didHitBarrier = NO;
  dispatch_barrier_async([_ASDisplayLayer displayQueue], ^{
    __atomic_store_n(&didHitBarrier, YES, __ATOMIC_SEQ_CST);
  });
  XCTAssertTrue(ASDisplayNodeRunRunLoopUntilBlockIsTrue(^BOOL{ return __atomic_load_n(&didHitBarrier, __ATOMIC_SEQ_CST); }));
}

- (void)waitForLayer:(_ASDisplayLayerTestLayer *)layer asyncDisplayCount:(NSUInteger)count
{
  // make sure we don't lock up the tests indefinitely; fail after 1 sec of waiting for the setContents async count to increment
  // NOTE: the layer sets its contents async back on the main queue, so we need to wait for main
  XCTAssertTrue(ASDisplayNodeRunRunLoopUntilBlockIsTrue(^BOOL{
    return (layer.setContentsAsyncCount == count);
  }));
}

- (void)waitForAsyncDelegate:(_ASDisplayLayerTestDelegate *)asyncDelegate
{
  XCTAssertTrue(ASDisplayNodeRunRunLoopUntilBlockIsTrue(^BOOL{
    return (asyncDelegate.didDisplayCount == 1);
  }));
}

- (void)checkDelegateDisplay:(BOOL)displaysAsynchronously
{
  [_ASDisplayLayerTestDelegate setClassModes:_ASDisplayLayerTestDelegateClassModeDisplay];
  _ASDisplayLayerTestDelegate *asyncDelegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:_ASDisplayLayerTestDelegateModeDidDisplay | _ASDisplayLayerTestDelegateModeDrawParameters];

  _ASDisplayLayerTestLayer *layer = (_ASDisplayLayerTestLayer *)asyncDelegate.layer;
  layer.displaysAsynchronously = displaysAsynchronously;

  if (displaysAsynchronously) {
    dispatch_suspend([_ASDisplayLayer displayQueue]);
  }
  layer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
  [layer setNeedsDisplay];
  [layer displayIfNeeded];

  if (displaysAsynchronously) {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
    XCTAssertEqual(layer.displayCount, 1u);
    XCTAssertEqual(layer.drawInContextCount, 0u);
    dispatch_resume([_ASDisplayLayer displayQueue]);
    [self waitForDisplayQueue];
    [self waitForAsyncDelegate:asyncDelegate];
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:1], @"%@", layer.setContentsCounts);
  } else {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:1 asyncCount:0], @"%@", layer.setContentsCounts);
  }

  XCTAssertFalse(layer.needsDisplay);
  XCTAssertEqual(layer.displayCount, 1u);
  XCTAssertEqual(layer.drawInContextCount, 0u);
  XCTAssertEqual(asyncDelegate.didDisplayCount, 1u);
  XCTAssertEqual(asyncDelegate.displayCount, 1u);

  [asyncDelegate release];
}

- (void)testDelegateDisplaySync
{
  [self checkDelegateDisplay:NO];
}

- (void)testDelegateDisplayAsync
{
  [self checkDelegateDisplay:YES];
}

- (void)checkDelegateDrawInContext:(BOOL)displaysAsynchronously
{
  [_ASDisplayLayerTestDelegate setClassModes:_ASDisplayLayerTestDelegateClassModeDrawInContext];
  _ASDisplayLayerTestDelegate *asyncDelegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:_ASDisplayLayerTestDelegateModeDidDisplay | _ASDisplayLayerTestDelegateModeDrawParameters];

  _ASDisplayLayerTestLayer *layer = (_ASDisplayLayerTestLayer *)asyncDelegate.layer;
  layer.displaysAsynchronously = displaysAsynchronously;

  if (displaysAsynchronously) {
    dispatch_suspend([_ASDisplayLayer displayQueue]);
  }
  layer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
  [layer setNeedsDisplay];
  [layer displayIfNeeded];

  if (displaysAsynchronously) {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
    XCTAssertEqual(layer.displayCount, 1u);
    XCTAssertEqual(layer.drawInContextCount, 0u);
    XCTAssertEqual(asyncDelegate.drawRectCount, 0u);
    dispatch_resume([_ASDisplayLayer displayQueue]);
    [self waitForLayer:layer asyncDisplayCount:1];
    [self waitForAsyncDelegate:asyncDelegate];
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:1], @"%@", layer.setContentsCounts);
  } else {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:1 asyncCount:0], @"%@", layer.setContentsCounts);
  }

  XCTAssertFalse(layer.needsDisplay);
  XCTAssertEqual(layer.displayCount, 1u);
  XCTAssertEqual(layer.drawInContextCount, 0u);
  XCTAssertEqual(asyncDelegate.didDisplayCount, 1u);
  XCTAssertEqual(asyncDelegate.displayCount, 0u);
  XCTAssertEqual(asyncDelegate.drawParametersCount, 1u);
  XCTAssertEqual(asyncDelegate.drawRectCount, 1u);

  [asyncDelegate release];
}

- (void)testDelegateDrawInContextSync
{
  [self checkDelegateDrawInContext:NO];
}

- (void)testDelegateDrawInContextAsync
{
  [self checkDelegateDrawInContext:YES];
}

- (void)checkDelegateDisplayAndDrawInContext:(BOOL)displaysAsynchronously
{
  [_ASDisplayLayerTestDelegate setClassModes:_ASDisplayLayerTestDelegateClassModeDisplay | _ASDisplayLayerTestDelegateClassModeDrawInContext];
  _ASDisplayLayerTestDelegate *asyncDelegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:_ASDisplayLayerTestDelegateModeDidDisplay | _ASDisplayLayerTestDelegateModeDrawParameters];

  _ASDisplayLayerTestLayer *layer = (_ASDisplayLayerTestLayer *)asyncDelegate.layer;
  layer.displaysAsynchronously = displaysAsynchronously;

  if (displaysAsynchronously) {
    dispatch_suspend([_ASDisplayLayer displayQueue]);
  }
  layer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
  [layer setNeedsDisplay];
  [layer displayIfNeeded];

  if (displaysAsynchronously) {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
    XCTAssertEqual(layer.displayCount, 1u);
    XCTAssertEqual(asyncDelegate.drawParametersCount, 1u);
    XCTAssertEqual(asyncDelegate.drawRectCount, 0u);
    dispatch_resume([_ASDisplayLayer displayQueue]);
    [self waitForDisplayQueue];
    [self waitForAsyncDelegate:asyncDelegate];
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:1], @"%@", layer.setContentsCounts);
  } else {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:1 asyncCount:0], @"%@", layer.setContentsCounts);
  }

  XCTAssertFalse(layer.needsDisplay);
  XCTAssertEqual(layer.displayCount, 1u);
  XCTAssertEqual(layer.drawInContextCount, 0u);
  XCTAssertEqual(asyncDelegate.didDisplayCount, 1u);
  XCTAssertEqual(asyncDelegate.displayCount, 1u);
  XCTAssertEqual(asyncDelegate.drawParametersCount, 1u);
  XCTAssertEqual(asyncDelegate.drawRectCount, 0u);

  [asyncDelegate release];
}

- (void)testDelegateDisplayAndDrawInContextSync
{
  [self checkDelegateDisplayAndDrawInContext:NO];
}

- (void)testDelegateDisplayAndDrawInContextAsync
{
  [self checkDelegateDisplayAndDrawInContext:YES];
}

- (void)testCancelAsyncDisplay
{
  [_ASDisplayLayerTestDelegate setClassModes:_ASDisplayLayerTestDelegateClassModeDisplay];
  _ASDisplayLayerTestDelegate *asyncDelegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:_ASDisplayLayerTestDelegateModeDidDisplay];
  _ASDisplayLayerTestLayer *layer = (_ASDisplayLayerTestLayer *)asyncDelegate.layer;

  dispatch_suspend([_ASDisplayLayer displayQueue]);
  layer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);
  [layer setNeedsDisplay];
  XCTAssertTrue(layer.needsDisplay);
  [layer displayIfNeeded];

  XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
  XCTAssertFalse(layer.needsDisplay);
  XCTAssertEqual(layer.displayCount, 1u);
  XCTAssertEqual(layer.drawInContextCount, 0u);

  [layer cancelAsyncDisplay];

  dispatch_resume([_ASDisplayLayer displayQueue]);
  [self waitForDisplayQueue];
  XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
  XCTAssertEqual(layer.displayCount, 1u);
  XCTAssertEqual(layer.drawInContextCount, 0u);
  XCTAssertEqual(asyncDelegate.didDisplayCount, 0u);
  XCTAssertEqual(asyncDelegate.displayCount, 0u);
  XCTAssertEqual(asyncDelegate.drawParametersCount, 0u);

  [asyncDelegate release];
}

/*- (void)testTransaction
{
  _ASDisplayLayerTestDelegateMode delegateModes = _ASDisplayLayerTestDelegateModeDidDisplay | _ASDisplayLayerTestDelegateModeDrawParameters;
  [_ASDisplayLayerTestDelegate setClassModes:_ASDisplayLayerTestDelegateClassModeDisplay];

  // Setup
  _ASDisplayLayerTestContainerLayer *containerLayer = [[_ASDisplayLayerTestContainerLayer alloc] init];
  containerLayer.asyncdisplaykit_asyncTransactionContainer = YES;
  containerLayer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);

  _ASDisplayLayerTestDelegate *layer1Delegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:delegateModes];
  _ASDisplayLayerTestLayer *layer1 = (_ASDisplayLayerTestLayer *)layer1Delegate.layer;
  layer1.displaysAsynchronously = YES;

  dispatch_semaphore_t displayAsyncLayer1Sema = dispatch_semaphore_create(0);
  layer1Delegate.displayLayerBlock = ^(_ASDisplayLayer *asyncLayer) {
    dispatch_semaphore_wait(displayAsyncLayer1Sema, DISPATCH_TIME_FOREVER);
    return bogusImage();
  };
  layer1.backgroundColor = [UIColor blackColor].CGColor;
  layer1.frame = CGRectMake(0.0, 0.0, 333.0, 123.0);
  [containerLayer addSublayer:layer1];

  _ASDisplayLayerTestDelegate *layer2Delegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:delegateModes];
  _ASDisplayLayerTestLayer *layer2 = (_ASDisplayLayerTestLayer *)layer2Delegate.layer;
  layer2.displaysAsynchronously = YES;
  layer2.backgroundColor = [UIColor blackColor].CGColor;
  layer2.frame = CGRectMake(0.0, 50.0, 97.0, 50.0);
  [containerLayer addSublayer:layer2];

  dispatch_suspend([_ASDisplayLayer displayQueue]);

  // display below if needed
  [layer1 setNeedsDisplay];
  [layer2 setNeedsDisplay];
  [containerLayer setNeedsDisplay];
  [self displayLayerRecursively:containerLayer];

  // check state before running displayQueue
  XCTAssertTrue([layer1 checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer1.setContentsCounts);
  XCTAssertEqual(layer1.displayCount, 1u);
  XCTAssertEqual(layer1Delegate.displayCount, 0u);
  XCTAssertTrue([layer2 checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer2.setContentsCounts);
  XCTAssertEqual(layer2.displayCount, 1u);
  XCTAssertEqual(layer1Delegate.displayCount, 0u);
  XCTAssertEqual(containerLayer.didCompleteTransactionCount, 0u);

  // run displayQueue until async display for layer2 has been run
  dispatch_resume([_ASDisplayLayer displayQueue]);
  XCTAssertTrue(ASDisplayNodeRunRunLoopUntilBlockIsTrue(^BOOL{
    return (layer2Delegate.displayCount == 1);
  }));

  // check layer1 has not had async display run
  XCTAssertTrue([layer1 checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer1.setContentsCounts);
  XCTAssertEqual(layer1.displayCount, 1u);
  XCTAssertEqual(layer1Delegate.displayCount, 0u);
  // check layer2 has had async display run
  XCTAssertTrue([layer2 checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer2.setContentsCounts);
  XCTAssertEqual(layer2.displayCount, 1u);
  XCTAssertEqual(layer2Delegate.displayCount, 1u);
  XCTAssertEqual(containerLayer.didCompleteTransactionCount, 0u);


  // allow layer1 to complete display
  dispatch_semaphore_signal(displayAsyncLayer1Sema);
  [self waitForLayer:layer1 asyncDisplayCount:1];

  // check that both layers have completed display
  XCTAssertTrue([layer1 checkSetContentsCountsWithSyncCount:0 asyncCount:1], @"%@", layer1.setContentsCounts);
  XCTAssertEqual(layer1.displayCount, 1u);
  XCTAssertEqual(layer1Delegate.displayCount, 1u);
  XCTAssertTrue([layer2 checkSetContentsCountsWithSyncCount:0 asyncCount:1], @"%@", layer2.setContentsCounts);
  XCTAssertEqual(layer2.displayCount, 1u);
  XCTAssertEqual(layer2Delegate.displayCount, 1u);

  XCTAssertTrue(ASDisplayNodeRunRunLoopUntilBlockIsTrue(^BOOL{
    return (containerLayer.didCompleteTransactionCount == 1);
  }));

  [containerLayer release];
  dispatch_release(displayAsyncLayer1Sema);
}*/

- (void)checkSuspendResume:(BOOL)displaysAsynchronously
{
  [_ASDisplayLayerTestDelegate setClassModes:_ASDisplayLayerTestDelegateClassModeDrawInContext];
  _ASDisplayLayerTestDelegate *asyncDelegate = [[_ASDisplayLayerTestDelegate alloc] initWithModes:_ASDisplayLayerTestDelegateModeDidDisplay | _ASDisplayLayerTestDelegateModeDrawParameters];

  _ASDisplayLayerTestLayer *layer = (_ASDisplayLayerTestLayer *)asyncDelegate.layer;
  layer.displaysAsynchronously = displaysAsynchronously;
  layer.frame = CGRectMake(0.0, 0.0, 100.0, 100.0);

  if (displaysAsynchronously) {
    dispatch_suspend([_ASDisplayLayer displayQueue]);
  }

  // Layer shouldn't display because display is suspended
  layer.displaySuspended = YES;
  [layer setNeedsDisplay];
  [layer displayIfNeeded];
  XCTAssertEqual(layer.displayCount, 0u, @"Should not have displayed because display is suspended, thus -setNeedsDisplay is a no-op");
  XCTAssertFalse(layer.needsDisplay, @"Should not need display");
  if (displaysAsynchronously) {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
    dispatch_resume([_ASDisplayLayer displayQueue]);
    [self waitForDisplayQueue];
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
  } else {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
  }
  XCTAssertFalse(layer.needsDisplay);
  XCTAssertEqual(layer.drawInContextCount, 0u);
  XCTAssertEqual(asyncDelegate.drawRectCount, 0u);

  // Layer should display because display is resumed
  if (displaysAsynchronously) {
    dispatch_suspend([_ASDisplayLayer displayQueue]);
  }
  layer.displaySuspended = NO;
  XCTAssertTrue(layer.needsDisplay);
  [layer displayIfNeeded];
  XCTAssertEqual(layer.displayCount, 1u);
  if (displaysAsynchronously) {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:0], @"%@", layer.setContentsCounts);
    XCTAssertEqual(layer.drawInContextCount, 0u);
    XCTAssertEqual(asyncDelegate.drawRectCount, 0u);
    dispatch_resume([_ASDisplayLayer displayQueue]);
    [self waitForLayer:layer asyncDisplayCount:1];
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:0 asyncCount:1], @"%@", layer.setContentsCounts);
  } else {
    XCTAssertTrue([layer checkSetContentsCountsWithSyncCount:1 asyncCount:0], @"%@", layer.setContentsCounts);
  }
  XCTAssertEqual(layer.drawInContextCount, 0u);
  XCTAssertEqual(asyncDelegate.drawParametersCount, 1u);
  XCTAssertEqual(asyncDelegate.drawRectCount, 1u);
  XCTAssertFalse(layer.needsDisplay);

  [asyncDelegate release];
}

- (void)testSuspendResumeAsync
{
  [self checkSuspendResume:YES];
}

- (void)testSuspendResumeSync
{
  [self checkSuspendResume:NO];
}

@end

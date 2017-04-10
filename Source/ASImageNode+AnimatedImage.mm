//
//  ASImageNode+AnimatedImage.mm
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/22/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASImageNode.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASImageNode+Private.h>
#import <AsyncDisplayKit/ASImageNode+AnimatedImagePrivate.h>
#import <AsyncDisplayKit/ASImageProtocols.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASNetworkImageNode.h>
#import <AsyncDisplayKit/ASWeakProxy.h>

#define ASAnimatedImageDebug  0

@interface ASNetworkImageNode (Private)
- (void)_locked_setDefaultImage:(UIImage *)image;
@end

NSString *const ASAnimatedImageDefaultRunLoopMode = NSRunLoopCommonModes;

@implementation ASImageNode (AnimatedImage)

#pragma mark - GIF support

- (void)setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  [self _locked_setAnimatedImage:animatedImage];
}

- (void)_locked_setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage
{
  if (ASObjectIsEqual(_animatedImage, animatedImage)) {
    return;
  }
  
  _animatedImage = animatedImage;
  
  if (animatedImage != nil) {
    __weak ASImageNode *weakSelf = self;
    if ([animatedImage respondsToSelector:@selector(setCoverImageReadyCallback:)]) {
      animatedImage.coverImageReadyCallback = ^(UIImage *coverImage) {
        // In this case the lock is already gone we have to call the unlocked version therefore
        [weakSelf setCoverImageCompleted:coverImage];
      };
    }
    
    if (animatedImage.playbackReady) {
      [self _locked_setShouldAnimate:YES];
    } else {
      animatedImage.playbackReadyCallback = ^{
        // In this case the lock is already gone we have to call the unlocked version therefore
        [self setShouldAnimate:YES];
      };
    }
  }
}

- (id <ASAnimatedImageProtocol>)animatedImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  return _animatedImage;
}

- (void)setAnimatedImagePaused:(BOOL)animatedImagePaused
{
  ASDN::MutexLocker l(_animatedImageLock);

  _animatedImagePaused = animatedImagePaused;

  [self _locked_setShouldAnimate:!animatedImagePaused];
}

- (BOOL)animatedImagePaused
{
  ASDN::MutexLocker l(_animatedImageLock);
  return _animatedImagePaused;
}

- (void)setCoverImageCompleted:(UIImage *)coverImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  [self _locked_setCoverImageCompleted:coverImage];
}

- (void)_locked_setCoverImageCompleted:(UIImage *)coverImage
{
  _displayLinkLock.lock();
  BOOL setCoverImage = (_displayLink == nil) || _displayLink.paused;
  _displayLinkLock.unlock();
  
  if (setCoverImage) {
    [self _locked_setCoverImage:coverImage];
  }
}

- (void)setCoverImage:(UIImage *)coverImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  [self _locked_setCoverImage:coverImage];
}

- (void)_locked_setCoverImage:(UIImage *)coverImage
{
  //If we're a network image node, we want to set the default image so
  //that it will correctly be restored if it exits the range.
  if ([self isKindOfClass:[ASNetworkImageNode class]]) {
    [(ASNetworkImageNode *)self _locked_setDefaultImage:coverImage];
  } else {
    [self _locked_setImage:coverImage];
  }
}

- (NSString *)animatedImageRunLoopMode
{
  ASDN::MutexLocker l(_displayLinkLock);
  return _animatedImageRunLoopMode;
}

- (void)setAnimatedImageRunLoopMode:(NSString *)runLoopMode
{
  ASDN::MutexLocker l(_displayLinkLock);

  if (runLoopMode == nil) {
    runLoopMode = ASAnimatedImageDefaultRunLoopMode;
  }

  if (_displayLink != nil) {
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:_animatedImageRunLoopMode];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:runLoopMode];
  }
  _animatedImageRunLoopMode = runLoopMode;
}

- (void)setShouldAnimate:(BOOL)shouldAnimate
{
  ASDN::MutexLocker l(_animatedImageLock);
  [self _locked_setShouldAnimate:shouldAnimate];
}

- (void)_locked_setShouldAnimate:(BOOL)shouldAnimate
{
  // This test is explicitly done and not ASPerformBlockOnMainThread as this would perform the block immediately
  // on main if called on main thread and we have to call methods locked or unlocked based on which thread we are on
  if (ASDisplayNodeThreadIsMain()) {
    if (shouldAnimate) {
      [self _locked_startAnimating];
    } else {
      [self _locked_stopAnimating];
    }
  } else {
    // We have to dispatch to the main thread and call the regular methods as the lock is already gone if the
    // block is called
    dispatch_async(dispatch_get_main_queue(), ^{
      if (shouldAnimate) {
        [self startAnimating];
      } else {
        [self stopAnimating];
      }
    });
  }
}

#pragma mark - Animating

- (void)startAnimating
{
  ASDisplayNodeAssertMainThread();

  ASDN::MutexLocker l(_animatedImageLock);
  [self _locked_startAnimating];
}

- (void)_locked_startAnimating
{
  // It should be safe to call self.interfaceState in this case as it will only grab the lock of the superclass
  if (!ASInterfaceStateIncludesVisible(self.interfaceState)) {
    return;
  }
  
  if (_animatedImagePaused) {
    return;
  }
  
  if (_animatedImage.playbackReady == NO) {
    return;
  }
  
#if ASAnimatedImageDebug
  NSLog(@"starting animation: %p", self);
#endif

  ASDN::MutexLocker l(_displayLinkLock);
  if (_displayLink == nil) {
    _playHead = 0;
    _displayLink = [CADisplayLink displayLinkWithTarget:[ASWeakProxy weakProxyWithTarget:self] selector:@selector(displayLinkFired:)];
    _displayLink.frameInterval = self.animatedImage.frameInterval;
    
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:_animatedImageRunLoopMode];
  } else {
    _displayLink.paused = NO;
  }
}

- (void)stopAnimating
{
  ASDisplayNodeAssertMainThread();
  
  ASDN::MutexLocker l(_animatedImageLock);
  [self _locked_stopAnimating];
}

- (void)_locked_stopAnimating
{
  ASDisplayNodeAssertMainThread();
  
#if ASAnimatedImageDebug
  NSLog(@"stopping animation: %p", self);
#endif
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(_displayLinkLock);
  _displayLink.paused = YES;
  self.lastDisplayLinkFire = 0;
  
  [_animatedImage clearAnimatedImageCache];
}

#pragma mark - ASDisplayNode

- (void)didEnterVisibleState
{
  ASDisplayNodeAssertMainThread();
  [super didEnterVisibleState];
  
  if (self.animatedImage.coverImageReady) {
    [self setCoverImage:self.animatedImage.coverImage];
  }
  [self startAnimating];
}

- (void)didExitVisibleState
{
  ASDisplayNodeAssertMainThread();
  [super didExitVisibleState];
  
  [self stopAnimating];
}

#pragma mark - Display Link Callbacks

- (void)displayLinkFired:(CADisplayLink *)displayLink
{
  ASDisplayNodeAssertMainThread();

  CFTimeInterval timeBetweenLastFire;
  if (self.lastDisplayLinkFire == 0) {
    timeBetweenLastFire = 0;
  } else {
    timeBetweenLastFire = CACurrentMediaTime() - self.lastDisplayLinkFire;
  }
  self.lastDisplayLinkFire = CACurrentMediaTime();
  
  _playHead += timeBetweenLastFire;
  
  while (_playHead > self.animatedImage.totalDuration) {
    _playHead -= self.animatedImage.totalDuration;
    _playedLoops++;
  }
  
  if (self.animatedImage.loopCount > 0 && _playedLoops >= self.animatedImage.loopCount) {
    [self stopAnimating];
    return;
  }
  
  NSUInteger frameIndex = [self frameIndexAtPlayHeadPosition:_playHead];
  CGImageRef frameImage = [self.animatedImage imageAtIndex:frameIndex];
  
  if (frameImage == nil) {
    _playHead -= timeBetweenLastFire;
    //Pause the display link until we get a file ready notification
    displayLink.paused = YES;
    self.lastDisplayLinkFire = 0;
  } else {
    self.contents = (__bridge id)frameImage;
  }
}

- (NSUInteger)frameIndexAtPlayHeadPosition:(CFTimeInterval)playHead
{
  ASDisplayNodeAssertMainThread();
  NSUInteger frameIndex = 0;
  for (NSUInteger durationIndex = 0; durationIndex < self.animatedImage.frameCount; durationIndex++) {
    playHead -= [self.animatedImage durationAtIndex:durationIndex];
    if (playHead < 0) {
      return frameIndex;
    }
    frameIndex++;
  }
  
  return frameIndex;
}

@end

#pragma mark - ASImageNode(AnimatedImageInvalidation)

@implementation ASImageNode(AnimatedImageInvalidation)

- (void)invalidateAnimatedImage
{
  ASDN::MutexLocker l(_displayLinkLock);
#if ASAnimatedImageDebug
  if (_displayLink) {
    NSLog(@"invalidating display link");
  }
#endif
  [_displayLink invalidate];
  _displayLink = nil;
}

@end

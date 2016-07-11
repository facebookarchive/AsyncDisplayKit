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

#import "ASImageNode.h"

#import "ASAssert.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeExtras.h"
#import "ASEqualityHelpers.h"
#import "ASImageNode+AnimatedImagePrivate.h"
#import "ASInternalHelpers.h"
#import "ASWeakProxy.h"

NSString *const ASAnimatedImageDefaultRunLoopMode = NSRunLoopCommonModes;

@implementation ASImageNode (AnimatedImage)

#pragma mark - GIF support

- (void)setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  if (ASObjectIsEqual(_animatedImage, animatedImage)) {
    return;
  }
  
  _animatedImage = animatedImage;
  
  if (animatedImage != nil) {
    __weak ASImageNode *weakSelf = self;
    if ([animatedImage respondsToSelector:@selector(setCoverImageReadyCallback:)]) {
      animatedImage.coverImageReadyCallback = ^(UIImage *coverImage) {
        [weakSelf coverImageCompleted:coverImage];
      };
    }
    
    if (animatedImage.playbackReady) {
      [self animatedImageFileReady];
    }

    animatedImage.playbackReadyCallback = ^{
      [weakSelf animatedImageFileReady];
    };
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
  ASPerformBlockOnMainThread(^{
    if (animatedImagePaused) {
      [self stopAnimating];
    } else {
      [self startAnimating];
    }
  });
}

- (BOOL)animatedImagePaused
{
  ASDN::MutexLocker l(_animatedImageLock);
  return _animatedImagePaused;
}

- (void)coverImageCompleted:(UIImage *)coverImage
{
  BOOL setCoverImage = YES;
  {
    ASDN::MutexLocker l(_displayLinkLock);
    if (_displayLink != nil && _displayLink.paused == NO) {
      setCoverImage = NO;
    }
  }
  
  if (setCoverImage) {
    self.image = coverImage;
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

- (void)animatedImageFileReady
{
  ASPerformBlockOnMainThread(^{
    [self startAnimating];
  });
}

- (void)startAnimating
{
  ASDisplayNodeAssertMainThread();
  if (ASInterfaceStateIncludesVisible(self.interfaceState) == NO) {
    return;
  }
  
  if (self.animatedImagePaused) {
    return;
  }
  
  if (self.animatedImage.playbackReady == NO) {
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
#if ASAnimatedImageDebug
  NSLog(@"stopping animation: %p", self);
#endif
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(_displayLinkLock);
  _displayLink.paused = YES;
  self.lastDisplayLinkFire = 0;
  
  [self.animatedImage clearAnimatedImageCache];
}

- (void)visibleStateDidChange:(BOOL)isVisible
{
  [super visibleStateDidChange:isVisible];
  
  ASDisplayNodeAssertMainThread();
  if (isVisible) {
    if (self.animatedImage.coverImageReady) {
      self.image = self.animatedImage.coverImage;
    }
    [self startAnimating];
  } else {
    [self stopAnimating];
  }
}

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

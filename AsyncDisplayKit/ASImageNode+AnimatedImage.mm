//
//  ASImageNode+AnimatedImage.m
//  Pods
//
//  Created by Garrett Moon on 3/22/16.
//
//

#import "ASImageNode+AnimatedImage.h"

#import "ASAssert.h"
#import "ASImageProtocols.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeExtras.h"
#import "ASEqualityHelpers.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASImageNode+AnimatedImagePrivate.h"

@interface ASWeakProxy : NSObject

@property (nonatomic, weak, readonly) id target;

+ (instancetype)weakProxyWithTarget:(id)target;

@end

@implementation ASImageNode (AnimatedImage)

#pragma mark - GIF support

- (void)setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  if (!ASObjectIsEqual(_animatedImage, animatedImage)) {
    _animatedImage = animatedImage;
  }
  if (animatedImage != nil) {
    if ([animatedImage respondsToSelector:@selector(setCoverImageReadyCallback:)]) {
      animatedImage.coverImageReadyCallback = ^(UIImage *coverImage) {
        [self coverImageCompleted:coverImage];
      };
    }
    
    animatedImage.playbackReadyCallback = ^{
      [self animatedImageFileReady];
    };
  }
}

- (id <ASAnimatedImageProtocol>)animatedImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  return _animatedImage;
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

- (void)animatedImageFileReady
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self startAnimating];
  });
}

- (void)startAnimating
{
  ASDisplayNodeAssertMainThread();
  if (ASInterfaceStateIncludesVisible(self.interfaceState) == NO) {
    return;
  }
  
  if (self.animatedImagePaused == YES) {
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
    
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
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

- (void)visibilityDidChange:(BOOL)isVisible
{
  [super visibilityDidChange:isVisible];
  
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

- (void)__enterHierarchy
{
  [super __enterHierarchy];
  [self startAnimating];
}

- (void)__exitHierarchy
{
  [super __exitHierarchy];
  [self stopAnimating];
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

- (void)dealloc
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

@implementation ASWeakProxy

- (instancetype)initWithTarget:(id)target
{
  if (self = [super init]) {
    _target = target;
  }
  return self;
}

+ (instancetype)weakProxyWithTarget:(id)target
{
  return [[ASWeakProxy alloc] initWithTarget:target];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  return _target;
}

@end

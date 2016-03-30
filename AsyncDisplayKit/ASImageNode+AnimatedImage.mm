//
//  ASImageNode+AnimatedImage.m
//  Pods
//
//  Created by Garrett Moon on 3/22/16.
//
//

#import "ASImageNode+AnimatedImage.h"

#import "ASAssert.h"
#import "ASAnimatedImage.h"
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

- (void)setAnimatedImage:(ASAnimatedImage *)animatedImage
{
  ASDN::MutexLocker l(_animatedImageLock);
  if (!ASObjectIsEqual(_animatedImage, animatedImage)) {
    _animatedImage = animatedImage;
  }
  if (animatedImage != nil) {
    animatedImage.infoCompletion = ^(UIImage *coverImage) {
      [self coverImageCompleted:coverImage];
    };
    
    animatedImage.fileReady = ^{
      [self animatedImageFileReady];
    };
  }
}

- (ASAnimatedImage *)animatedImage
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
  
  if (self.animatedImage.status != ASAnimatedImageStatusProcessed && self.animatedImage.status != ASAnimatedImageStatusFirstFileProcessed) {
    return;
  }
  
#if ASAnimatedImageDebug
  NSLog(@"starting animation: %p", self);
#endif
  ASDN::MutexLocker l(_displayLinkLock);
  if (_displayLink == nil) {
    _playHead = 0;
    _displayLink = [CADisplayLink displayLinkWithTarget:[ASWeakProxy weakProxyWithTarget:self] selector:@selector(displayLinkFired:)];
    
    //Credit to FLAnimatedImage (https://github.com/Flipboard/FLAnimatedImage) for display link interval calculations
    _displayLink.frameInterval = MAX([self frameDelayGreatestCommonDivisor] * kASAnimatedImageDisplayRefreshRate, 1);
    
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
  
  [self.animatedImage clearMemoryCache];
}

- (void)visibilityDidChange:(BOOL)isVisible
{
  [super visibilityDidChange:isVisible];
  
  ASDisplayNodeAssertMainThread();
  if (isVisible) {
    if (self.animatedImage.status == ASAnimatedImageStatusInfoProcessed || self.animatedImage.status == ASAnimatedImageStatusFirstFileProcessed || self.animatedImage.status == ASAnimatedImageStatusProcessed) {
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

//Credit to FLAnimatedImage (https://github.com/Flipboard/FLAnimatedImage) for display link interval calculations
- (NSTimeInterval)frameDelayGreatestCommonDivisor
{
  const NSTimeInterval kGreatestCommonDivisorPrecision = 2.0 / kASAnimatedImageMinimumDuration;
  
  // Scales the frame delays by `kGreatestCommonDivisorPrecision`
  // then converts it to an UInteger for in order to calculate the GCD.
  NSUInteger scaledGCD = lrint(self.animatedImage.durations[0] * kGreatestCommonDivisorPrecision);
  for (NSUInteger durationIdx = 0; durationIdx < self.animatedImage.frameCount; durationIdx++) {
    Float32 duration = self.animatedImage.durations[durationIdx];
    scaledGCD = gcd(lrint(duration * kGreatestCommonDivisorPrecision), scaledGCD);
  }
  
  // Reverse to scale to get the value back into seconds.
  return scaledGCD / kGreatestCommonDivisorPrecision;
}

//Credit to FLAnimatedImage (https://github.com/Flipboard/FLAnimatedImage) for display link interval calculations
static NSUInteger gcd(NSUInteger a, NSUInteger b)
{
  // http://en.wikipedia.org/wiki/Greatest_common_divisor
  if (a < b) {
    return gcd(b, a);
  } else if (a == b) {
    return b;
  }
  
  while (true) {
    NSUInteger remainder = a % b;
    if (remainder == 0) {
      return b;
    }
    a = b;
    b = remainder;
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
    playHead -= self.animatedImage.durations[durationIndex];
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

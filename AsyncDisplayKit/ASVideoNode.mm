/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */
#if TARGET_OS_IOS
#import "ASVideoNode.h"
#import "ASDefaultPlayButton.h"

static BOOL ASAssetIsEqual(AVAsset *asset1, AVAsset *asset2) {
  return ASObjectIsEqual(asset1, asset2)
  || ([asset1 isKindOfClass:[AVURLAsset class]]
      && [asset2 isKindOfClass:[AVURLAsset class]]
      && ASObjectIsEqual(((AVURLAsset *)asset1).URL, ((AVURLAsset *)asset2).URL));
}

static UIViewContentMode ASContentModeFromVideoGravity(NSString *videoGravity) {
  if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    return UIViewContentModeScaleAspectFill;
  } else if ([videoGravity isEqualToString:AVLayerVideoGravityResize]) {
    return UIViewContentModeScaleToFill;
  } else {
    return UIViewContentModeScaleAspectFit;
  }
}

static void *ASVideoNodeContext = &ASVideoNodeContext;
static NSString * const kPlaybackLikelyToKeepUpKey = @"playbackLikelyToKeepUp";
static NSString * const kplaybackBufferEmpty = @"playbackBufferEmpty";
static NSString * const kStatus = @"status";

@interface ASVideoNode ()
{
  ASDN::RecursiveMutex _videoLock;
  
  __weak id<ASVideoNodeDelegate> _delegate;
  struct {
    unsigned int delegateVideNodeShouldChangePlayerStateTo:1;
    unsigned int delegateVideoPlaybackDidFinish:1;
    unsigned int delegateVideoNodeWasTapped:1;
    unsigned int delegateVideoNodeWillChangePlayerStateToState:1;
    unsigned int delegateVideoNodeDidPlayToSecond:1;
  } _delegateFlags;
  
  BOOL _shouldBePlaying;
  
  BOOL _shouldAutorepeat;
  BOOL _shouldAutoplay;
  
  BOOL _muted;
  
  ASVideoNodePlayerState _playerState;
  
  AVAsset *_asset;
  
  AVPlayerItem *_currentPlayerItem;
  AVPlayer *_player;
  
  id _timeObserver;
  int32_t _periodicTimeObserverTimescale;
  CMTime _timeObserverInterval;
  
  ASImageNode *_placeholderImageNode; // TODO: Make ASVideoNode an ASImageNode subclass; remove this.
  
  ASButtonNode *_playButtonNode;
  ASDisplayNode *_playerNode;
  ASDisplayNode *_spinnerNode;
  NSString *_gravity;
}

@end

@implementation ASVideoNode

// TODO: Support preview images with HTTP Live Streaming videos.

#pragma mark - Construction and Layout

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  self.playButton = [[ASDefaultPlayButton alloc] init];
  self.gravity = AVLayerVideoGravityResizeAspect;
  _periodicTimeObserverTimescale = 10000;
  [self addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
  
  return self;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (ASDisplayNode *)constructPlayerNode
{
  ASVideoNode * __weak weakSelf = self;

  return [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
    AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
    playerLayer.player = weakSelf.player;
    playerLayer.videoGravity = weakSelf.gravity;
    return playerLayer;
  }];
}

- (AVPlayerItem *)constructPlayerItem
{
  ASDN::MutexLocker l(_videoLock);

  if (_asset != nil) {
    return [[AVPlayerItem alloc] initWithAsset:_asset];
  }

  return nil;
}

- (void)prepareToPlayAsset:(AVAsset *)asset withKeys:(NSArray<NSString *> *)requestedKeys
{
  for (NSString *key in requestedKeys) {
    NSError *error = nil;
    AVKeyValueStatus keyStatus = [asset statusOfValueForKey:key error:&error];
    if (keyStatus == AVKeyValueStatusFailed) {
      NSLog(@"Asset loading failed with error: %@", error);
    }
  }
  
  if (![asset isPlayable]) {
    NSLog(@"Asset is not playable.");
    return;
  }

  AVPlayerItem *playerItem = [self constructPlayerItem];
  [self setCurrentItem:playerItem];
  
  if (_player != nil) {
    [_player replaceCurrentItemWithPlayerItem:playerItem];
  } else {
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
  }
  
  if (_placeholderImageNode.image == nil) {
    [self generatePlaceholderImage];
  }
  
  __weak __typeof(self) weakSelf = self;
  _timeObserverInterval = CMTimeMake(1, _periodicTimeObserverTimescale);
  _timeObserver = [_player addPeriodicTimeObserverForInterval:_timeObserverInterval queue:NULL usingBlock:^(CMTime time){
    [weakSelf periodicTimeObserver:time];
  }];
}

- (void)addPlayerItemObservers:(AVPlayerItem *)playerItem
{
  [playerItem addObserver:self forKeyPath:kStatus options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:ASVideoNodeContext];
  [playerItem addObserver:self forKeyPath:kPlaybackLikelyToKeepUpKey options:NSKeyValueObservingOptionNew context:ASVideoNodeContext];
  [playerItem addObserver:self forKeyPath:kplaybackBufferEmpty options:NSKeyValueObservingOptionNew context:ASVideoNodeContext];
  
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(didPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
  [notificationCenter addObserver:self selector:@selector(errorWhilePlaying:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:playerItem];
  [notificationCenter addObserver:self selector:@selector(errorWhilePlaying:) name:AVPlayerItemNewErrorLogEntryNotification object:playerItem];
}

- (void)removePlayerItemObservers:(AVPlayerItem *)playerItem
{
  @try {
    [playerItem removeObserver:self forKeyPath:kStatus context:ASVideoNodeContext];
    [playerItem removeObserver:self forKeyPath:kPlaybackLikelyToKeepUpKey context:ASVideoNodeContext];
    [playerItem removeObserver:self forKeyPath:kplaybackBufferEmpty context:ASVideoNodeContext];
  }
  @catch (NSException * __unused exception) {
    NSLog(@"Unnecessary KVO removal");
  }

  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
  [notificationCenter removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:playerItem];
  [notificationCenter removeObserver:self name:AVPlayerItemNewErrorLogEntryNotification object:playerItem];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    // All subnodes should taking the whole node frame
    CGSize maxSize = constrainedSize.max;
    if (!CGSizeEqualToSize(self.preferredFrameSize, CGSizeZero)) {
        maxSize = self.preferredFrameSize;
    }
    
    // Prevent crashes through if infinite width or height
    if (isinf(maxSize.width) || isinf(maxSize.height)) {
        ASDisplayNodeAssert(NO, @"Infinite width or height in ASVideoNode");
        maxSize = CGSizeZero;
    }
    
    // Stretch out play button, placeholder image player node to the max size
    NSMutableArray *children = [NSMutableArray array];
    if (_playButtonNode) {
        _playButtonNode.preferredFrameSize = maxSize;
        [children addObject:_playButtonNode];
    }
    if (_placeholderImageNode) {
        _placeholderImageNode.preferredFrameSize = maxSize;
        [children addObject:_placeholderImageNode];
    }
    if (_playerNode) {
        _playerNode.preferredFrameSize = maxSize;
        [children addObject:_playerNode];
    }
    
    // Center spinner node
    if (_spinnerNode) {
        ASCenterLayoutSpec *centerLayoutSpec = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionDefault child:_spinnerNode];
        centerLayoutSpec.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(maxSize);
        [children addObject:centerLayoutSpec];
    }
    
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:children];
}

- (void)layout
{
  [super layout];
  
  CGRect bounds = self.bounds;
  
  ASDN::MutexLocker l(_videoLock);
  CGFloat horizontalDiff = (CGRectGetWidth(bounds) - CGRectGetWidth(_playButtonNode.bounds))/2;
  CGFloat verticalDiff = (CGRectGetHeight(bounds) - CGRectGetHeight(_playButtonNode.bounds))/2;
  _playButtonNode.hitTestSlop = UIEdgeInsetsMake(-verticalDiff, -horizontalDiff, -verticalDiff, -horizontalDiff);
}

- (void)generatePlaceholderImage
{
  ASVideoNode * __weak weakSelf = self;
  AVAsset * __weak asset = self.asset;

  [self imageAtTime:kCMTimeZero completionHandler:^(UIImage *image) {
    ASPerformBlockOnMainThread(^{
      // Ensure the asset hasn't changed since the image request was made
      if (ASAssetIsEqual(weakSelf.asset, asset)) {
        [weakSelf setVideoPlaceholderImage:image];
      }
    });
  }];
}

- (void)imageAtTime:(CMTime)imageTime completionHandler:(void(^)(UIImage *image))completionHandler
{
  ASPerformBlockOnBackgroundThread(^{
    AVAsset *asset = self.asset;

    // Skip the asset image generation if we don't have any tracks available that are capable of supporting it
    NSArray<AVAssetTrack *>* visualAssetArray = [asset tracksWithMediaCharacteristic:AVMediaCharacteristicVisual];
    if (visualAssetArray.count == 0) {
      completionHandler(nil);
      return;
    }

    AVAssetImageGenerator *previewImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    previewImageGenerator.appliesPreferredTrackTransform = YES;

    [previewImageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:imageTime]]
                                                completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
                                                  if (error != nil && result != AVAssetImageGeneratorCancelled) {
                                                    NSLog(@"Asset preview image generation failed with error: %@", error);
                                                  }
                                                  completionHandler(image ? [UIImage imageWithCGImage:image] : nil);
                                                }];
  });
}

- (void)setVideoPlaceholderImage:(UIImage *)image
{
  ASDN::MutexLocker l(_videoLock);

  if (_placeholderImageNode == nil && image != nil) {
    _placeholderImageNode = [[ASImageNode alloc] init];
    _placeholderImageNode.layerBacked = YES;
    _placeholderImageNode.contentMode = ASContentModeFromVideoGravity(_gravity);
  }

  _placeholderImageNode.image = image;

  ASPerformBlockOnMainThread(^{
    ASDN::MutexLocker l(_videoLock);

    if (_placeholderImageNode != nil) {
      [self insertSubnode:_placeholderImageNode atIndex:0];
      [self setNeedsLayout];
    }
  });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  ASDN::MutexLocker l(_videoLock);

  if (object != _currentPlayerItem) {
    return;
  }

  if ([keyPath isEqualToString:kStatus]) {
    if ([change[NSKeyValueChangeNewKey] integerValue] == AVPlayerItemStatusReadyToPlay) {
      [self removeSpinner];
      // If we don't yet have a placeholder image update it now that we should have data available for it
      if (_placeholderImageNode.image == nil) {
        [self generatePlaceholderImage];
      }
      if (_shouldBePlaying) {
        self.playerState = ASVideoNodePlayerStatePlaying;
      }
    }
  } else if ([keyPath isEqualToString:kPlaybackLikelyToKeepUpKey]) {
    if (_shouldBePlaying && [change[NSKeyValueChangeNewKey] boolValue] == true && ASInterfaceStateIncludesVisible(self.interfaceState)) {
      [self play]; // autoresume after buffer catches up
    }
  } else if ([keyPath isEqualToString:kplaybackBufferEmpty]) {
    if (_shouldBePlaying && [change[NSKeyValueChangeNewKey] boolValue] == true && ASInterfaceStateIncludesVisible(self.interfaceState)) {
      self.playerState = ASVideoNodePlayerStateLoading;
      [self showSpinner];
    }
  }
}

- (void)tapped
{
  if (_delegateFlags.delegateVideoNodeWasTapped) {
    [_delegate videoNodeWasTapped:self];
  } else {
    if (_shouldBePlaying) {
      [self pause];
    } else {
      [self play];
    }
  }
}

- (void)fetchData
{
  [super fetchData];
  
  {
  ASDN::MutexLocker l(_videoLock);
  AVAsset *asset = self.asset;
  NSArray<NSString *> *requestedKeys = @[ @"playable" ];
  [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
    ASPerformBlockOnMainThread(^{
      [self prepareToPlayAsset:asset withKeys:requestedKeys];
    });
  }];
  }
}

- (void)periodicTimeObserver:(CMTime)time
{
  NSTimeInterval timeInSeconds = CMTimeGetSeconds(time);
  if (timeInSeconds <= 0) {
    return;
  }
  
  if (_delegateFlags.delegateVideoNodeDidPlayToSecond) {
    [_delegate videoNode:self didPlayToSecond:timeInSeconds];
  }
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  
  {
    ASDN::MutexLocker l(_videoLock);

    self.player = nil;
    self.currentItem = nil;
    _placeholderImageNode.image = nil;
  }
}

- (void)visibilityDidChange:(BOOL)isVisible
{
  [super visibilityDidChange:isVisible];
  
  ASDN::MutexLocker l(_videoLock);
  
  if (isVisible) {
    if (_shouldBePlaying || _shouldAutoplay) {
      [self play];
    }
  } else if (_shouldBePlaying) {
    [self pause];
    _shouldBePlaying = YES;
  }
}


#pragma mark - Video Properties

- (void)setPlayerState:(ASVideoNodePlayerState)playerState
{
  ASDN::MutexLocker l(_videoLock);
  
  ASVideoNodePlayerState oldState = _playerState;
  
  if (oldState == playerState) {
    return;
  }
  
  if (_delegateFlags.delegateVideoNodeWillChangePlayerStateToState) {
    [_delegate videoNode:self willChangePlayerState:oldState toState:playerState];
  }
  
  _playerState = playerState;
}

- (void)setPlayButton:(ASButtonNode *)playButton
{
  ASDN::MutexLocker l(_videoLock);

  [_playButtonNode removeTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
  [_playButtonNode removeFromSupernode];

  _playButtonNode = playButton;
  [_playButtonNode addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];

  [self addSubnode:playButton];
  [self setNeedsLayout];
}

- (ASButtonNode *)playButton
{
  ASDN::MutexLocker l(_videoLock);
  return _playButtonNode;
}

- (void)setAsset:(AVAsset *)asset
{
  ASDN::MutexLocker l(_videoLock);
  
  if (ASAssetIsEqual(asset, _asset)) {
    return;
  }

  [self clearFetchedData];

  _asset = asset;

  [self setNeedsDataFetch];

  if (_shouldAutoplay) {
    [self play];
  }
}

- (AVAsset *)asset
{
  ASDN::MutexLocker l(_videoLock);
  return _asset;
}

- (AVPlayer *)player
{
  ASDN::MutexLocker l(_videoLock);
  return _player;
}

- (id<ASVideoNodeDelegate>)delegate{
  return _delegate;
}

- (void)setDelegate:(id<ASVideoNodeDelegate>)delegate
{
  _delegate = delegate;
  if (_delegate == nil) {
    memset(&_delegateFlags, 0, sizeof(_delegateFlags));
  } else {
    _delegateFlags.delegateVideNodeShouldChangePlayerStateTo = [_delegate respondsToSelector:@selector(videoNode:shouldChangePlayerStateTo:)];
    _delegateFlags.delegateVideoPlaybackDidFinish = [_delegate respondsToSelector:@selector(videoPlaybackDidFinish:)];
    _delegateFlags.delegateVideoNodeWasTapped = [_delegate respondsToSelector:@selector(videoNodeWasTapped:)];
    _delegateFlags.delegateVideoNodeWillChangePlayerStateToState = [_delegate respondsToSelector:@selector(videoNode:willChangePlayerState:toState:)];
    _delegateFlags.delegateVideoNodeDidPlayToSecond = [_delegate respondsToSelector:@selector(videoNode:didPlayToSecond:)];
  }
}

- (void)setGravity:(NSString *)gravity
{
  ASDN::MutexLocker l(_videoLock);
  if (_playerNode.isNodeLoaded) {
    ((AVPlayerLayer *)_playerNode.layer).videoGravity = gravity;
  }
  _placeholderImageNode.contentMode = ASContentModeFromVideoGravity(gravity);
  _gravity = gravity;
}

- (NSString *)gravity
{
  ASDN::MutexLocker l(_videoLock);
  return _gravity;
}

- (BOOL)muted
{
  ASDN::MutexLocker l(_videoLock);
  return _muted;
}

- (void)setMuted:(BOOL)muted
{
  ASDN::MutexLocker l(_videoLock);
  
  _player.muted = muted;
  _muted = muted;
}

#pragma mark - Video Playback

- (void)play
{
  ASDN::MutexLocker l(_videoLock);

  if (![self isStateChangeValid:ASVideoNodePlayerStatePlaying]) {
    return;
  }

  if (_player == nil) {
    [self setNeedsDataFetch];
  }

  if (_playerNode == nil) {
    _playerNode = [self constructPlayerNode];

    if (_playButtonNode.supernode == self) {
      [self insertSubnode:_playerNode belowSubnode:_playButtonNode];
    } else {
      [self addSubnode:_playerNode];
    }
      
    [self setNeedsLayout];
  }
  
  
  [_player play];
  _shouldBePlaying = YES;
  
  [UIView animateWithDuration:0.15 animations:^{
    _playButtonNode.alpha = 0.0;
  }];
  if (![self ready]) {
    [self showSpinner];
  } else {
    [self removeSpinner];
    self.playerState = ASVideoNodePlayerStatePlaying;
  }
}

- (BOOL)ready
{
  return _currentPlayerItem.status == AVPlayerItemStatusReadyToPlay;
}

- (void)showSpinner
{
  ASDN::MutexLocker l(_videoLock);
  
  if (!_spinnerNode) {
    _spinnerNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      UIActivityIndicatorView *spinnnerView = [[UIActivityIndicatorView alloc] init];
      spinnnerView.color = [UIColor whiteColor];
      return spinnnerView;
    }];
    _spinnerNode.preferredFrameSize = CGSizeMake(44.0, 44.0);
      
    [self addSubnode:_spinnerNode];
    [self setNeedsLayout];
  }
  [(UIActivityIndicatorView *)_spinnerNode.view startAnimating];
}

- (void)removeSpinner
{
  ASDN::MutexLocker l(_videoLock);
  
  if (!_spinnerNode) {
    return;
  }
  [_spinnerNode removeFromSupernode];
  _spinnerNode = nil;
}

- (void)pause
{
  ASDN::MutexLocker l(_videoLock);
  if (![self isStateChangeValid:ASVideoNodePlayerStatePaused]) {
    return;
  }
  self.playerState = ASVideoNodePlayerStatePaused;
  [_player pause];
  [self removeSpinner];
  _shouldBePlaying = NO;
  [UIView animateWithDuration:0.15 animations:^{
    _playButtonNode.alpha = 1.0;
  }];
}

- (BOOL)isPlaying
{
  ASDN::MutexLocker l(_videoLock);
  
  return (_player.rate > 0 && !_player.error);
}

- (BOOL)isStateChangeValid:(ASVideoNodePlayerState)state
{
  if (_delegateFlags.delegateVideNodeShouldChangePlayerStateTo) {
    if (![_delegate videoNode:self shouldChangePlayerStateTo:state]) {
      return NO;
    }
  }
  return YES;
}


#pragma mark - Playback observers

- (void)didPlayToEnd:(NSNotification *)notification
{
  self.playerState = ASVideoNodePlayerStateFinished;
  if (_delegateFlags.delegateVideoPlaybackDidFinish) {
    [_delegate videoPlaybackDidFinish:self];
  }
  [_player seekToTime:kCMTimeZero];

  if (_shouldAutorepeat) {
    [self play];
  } else {
    [self pause];
  }
}

- (void)errorWhilePlaying:(NSNotification *)notification
{
  if ([notification.name isEqualToString:AVPlayerItemFailedToPlayToEndTimeNotification]) {
    NSLog(@"Failed to play video");
  } else if ([notification.name isEqualToString:AVPlayerItemNewErrorLogEntryNotification]) {
    AVPlayerItem *item = (AVPlayerItem *)notification.object;
    AVPlayerItemErrorLogEvent *logEvent = item.errorLog.events.lastObject;
    NSLog(@"AVPlayerItem error log entry added for video with error %@ status %@", item.error,
          (item.status == AVPlayerItemStatusFailed ? @"FAILED" : [NSString stringWithFormat:@"%ld", (long)item.status]));
    NSLog(@"Item is %@", item);
    
    if (logEvent) {
      NSLog(@"Log code %ld domain %@ comment %@", (long)logEvent.errorStatusCode, logEvent.errorDomain, logEvent.errorComment);
    }
  }
}

#pragma mark - Internal Properties

- (ASDisplayNode *)spinner
{
  ASDN::MutexLocker l(_videoLock);
  return _spinnerNode;
}

- (ASImageNode *)placeholderImageNode
{
  ASDN::MutexLocker l(_videoLock);
  return _placeholderImageNode;
}

- (AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_videoLock);
  return _currentPlayerItem;
}

- (void)setCurrentItem:(AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_videoLock);

  [self removePlayerItemObservers:_currentPlayerItem];

  _currentPlayerItem = currentItem;

  [self addPlayerItemObservers:currentItem];
}

- (ASDisplayNode *)playerNode
{
  ASDN::MutexLocker l(_videoLock);
  return _playerNode;
}

- (void)setPlayerNode:(ASDisplayNode *)playerNode
{
  ASDN::MutexLocker l(_videoLock);
  _playerNode = playerNode;
    
  [self setNeedsLayout];
}

- (void)setPlayer:(AVPlayer *)player
{
  ASDN::MutexLocker l(_videoLock);
  _player = player;
  player.muted = _muted;
  ((AVPlayerLayer *)_playerNode.layer).player = player;
}

- (BOOL)shouldBePlaying
{
  ASDN::MutexLocker l(_videoLock);
  return _shouldBePlaying;
}

- (void)setShouldBePlaying:(BOOL)shouldBePlaying
{
  ASDN::MutexLocker l(_videoLock);
  _shouldBePlaying = shouldBePlaying;
}

#pragma mark - Lifecycle

- (void)dealloc
{
  [_player removeTimeObserver:_timeObserver];
  _timeObserver = nil;
  [_playButtonNode removeTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
  [self removePlayerItemObservers:_currentPlayerItem];
}

@end
#endif

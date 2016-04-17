/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASVideoNode.h"
#import "ASDefaultPlayButton.h"

BOOL ASAssetIsEqual(AVAsset *asset1, AVAsset *asset2) {
  return ASObjectIsEqual(asset1, asset2)
  || ([asset1 isKindOfClass:[AVURLAsset class]]
      && [asset2 isKindOfClass:[AVURLAsset class]]
      && ASObjectIsEqual(((AVURLAsset *)asset1).URL, ((AVURLAsset *)asset2).URL));
}

@interface ASVideoNode ()
{
  ASDN::RecursiveMutex _videoLock;
  
  __weak id<ASVideoNodeDelegate> _delegate;

  BOOL _shouldBePlaying;
  
  BOOL _shouldAutorepeat;
  BOOL _shouldAutoplay;
  
  BOOL _muted;

  AVAsset *_asset;
  
  AVPlayerItem *_currentItem;
  AVPlayer *_player;
  
  ASImageNode *_placeholderImageNode;
  ASButtonNode *_playButton;
  ASDisplayNode *_playerNode;
  ASDisplayNode *_spinner;

  NSString *_gravity;
}

@end

@implementation ASVideoNode

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  self.playButton = [[ASDefaultPlayButton alloc] init];
  
  self.gravity = AVLayerVideoGravityResizeAspect;
  
  [self addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
    
  return self;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([change[NSKeyValueChangeNewKey] integerValue] == AVPlayerItemStatusReadyToPlay) {
    [_spinner removeFromSupernode];
    _spinner = nil;
  }
}

- (void)didPlayToEnd:(NSNotification *)notification
{
  if (ASObjectIsEqual([[notification object] asset], _asset)) {
    if ([_delegate respondsToSelector:@selector(videoPlaybackDidFinish:)]) {
      [_delegate videoPlaybackDidFinish:self];
    }
    [_player seekToTime:kCMTimeZero];
    
    if (_shouldAutorepeat) {
      [self play];
    } else {
      [self pause];
    }
  }
}

- (void)willEnterForeground:(NSNotification *)notification
{
  ASDN::MutexLocker l(_videoLock);

  if (_shouldBePlaying) {
    [self play];
  }
}

- (void)didEnterBackground:(NSNotification *)notification
{
  ASDN::MutexLocker l(_videoLock);

  if (_shouldBePlaying) {
    [self pause];
    _shouldBePlaying = YES;
  }
}

- (void)layout
{
  [super layout];
  
  CGRect bounds = self.bounds;
  
  _placeholderImageNode.frame = bounds;
  _playerNode.frame = bounds;
  _playerNode.layer.frame = bounds;
  
  _playButton.frame = bounds;
  
  CGFloat horizontalDiff = (bounds.size.width - _playButton.bounds.size.width)/2;
  CGFloat verticalDiff = (bounds.size.height - _playButton.bounds.size.height)/2;
  _playButton.hitTestSlop = UIEdgeInsetsMake(-verticalDiff, -horizontalDiff, -verticalDiff, -horizontalDiff);
  
  _spinner.bounds = CGRectMake(0, 0, 44, 44);
  _spinner.position = CGPointMake(bounds.size.width/2, bounds.size.height/2);
}

- (void)didLoad
{
  [super didLoad];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)tapped
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(videoNodeWasTapped:)]) {
    [self.delegate videoNodeWasTapped:self];
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

    if (_asset == nil) {
        return;
    }

    self.currentItem = [[AVPlayerItem alloc] initWithAsset:_asset];

    if (_player != nil) {
      [_player replaceCurrentItemWithPlayerItem:_currentItem];
    } else {
      self.player = [[AVPlayer alloc] initWithPlayerItem:_currentItem];
    }

    if (_placeholderImageNode.image == nil) {
      [self generatePlaceholderImage];
    }
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

- (void)setPlayButton:(ASButtonNode *)playButton
{
  ASDN::MutexLocker l(_videoLock);
  
  [_playButton removeTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
  [_playButton removeFromSupernode];

  _playButton = playButton;
  
  [self addSubnode:playButton];
  
  [_playButton addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
}

- (ASButtonNode *)playButton
{
  ASDN::MutexLocker l(_videoLock);
  
  return _playButton;
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

  if (_asset != nil && _shouldAutoplay) {
    [self play];
  }
}

- (AVAsset *)asset
{
  ASDN::MutexLocker l(_videoLock);
  return _asset;
}

- (void)setPlayer:(AVPlayer *)player
{
  ASDN::MutexLocker l(_videoLock);

  _player = player;
  player.muted = _muted;
  ((AVPlayerLayer *)_playerNode.layer).player = player;
}

- (AVPlayer *)player
{
  ASDN::MutexLocker l(_videoLock);
  return _player;
}

- (void)setGravity:(NSString *)gravity
{
  ASDN::MutexLocker l(_videoLock);

  _gravity = gravity;

  ((AVPlayerLayer *)_playerNode.layer).videoGravity = gravity;
  _placeholderImageNode.contentMode = [self contentModeFromVideoGravity:gravity];
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

  if (_player == nil) {
    [self setNeedsDataFetch];
  }

  if (_playerNode == nil) {
    _playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
      AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
      playerLayer.player = _player;
      playerLayer.videoGravity = _gravity;
      return playerLayer;
    }];

    if (_playButton.supernode == self) {
      [self insertSubnode:_playerNode belowSubnode:_playButton];
    } else {
      [self addSubnode:_playerNode];
    }
  }

  [_player play];
  _shouldBePlaying = YES;
  
  [UIView animateWithDuration:0.15 animations:^{
    _playButton.alpha = 0.0;
  }];
  
  if (![self ready]) {
    if (!_spinner) {
      _spinner = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
        UIActivityIndicatorView *spinnnerView = [[UIActivityIndicatorView alloc] init];
        spinnnerView.color = [UIColor whiteColor];

        return spinnnerView;
      }];

      [self addSubnode:_spinner];
    }

    [(UIActivityIndicatorView *)_spinner.view startAnimating];
  }
}

- (BOOL)ready
{
  return _currentItem.status == AVPlayerItemStatusReadyToPlay;
}

- (void)pause
{
  ASDN::MutexLocker l(_videoLock);
  
  [_player pause];
  [((UIActivityIndicatorView *)_spinner.view) stopAnimating];
  _shouldBePlaying = NO;
  [UIView animateWithDuration:0.15 animations:^{
    _playButton.alpha = 1.0;
  }];
}

- (BOOL)isPlaying
{
  ASDN::MutexLocker l(_videoLock);
  
  return (_player.rate > 0 && !_player.error);
}

#pragma mark - Internal Properties

- (ASDisplayNode *)spinner
{
  ASDN::MutexLocker l(_videoLock);
  return _spinner;
}

- (ASImageNode *)placeholderImageNode
{
  ASDN::MutexLocker l(_videoLock);
  return _placeholderImageNode;
}

- (AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_videoLock);
  return _currentItem;
}

- (void)setCurrentItem:(AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_videoLock);

  @try {
    [_currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
  }
  @catch (NSException * __unused exception) {
    NSLog(@"Unnecessary KVO observer removal in set current item");
  }

  _currentItem = currentItem;

  [_currentItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];
}

- (ASDisplayNode *)playerNode
{
  ASDN::MutexLocker l(_videoLock);
  return _playerNode;
}

- (BOOL)shouldBePlaying
{
  ASDN::MutexLocker l(_videoLock);
  return _shouldBePlaying;
}

#pragma mark - Lifecycle

- (void)dealloc
{
  [_playButton removeTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  @try {
    [_currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
  }
  @catch (NSException * __unused exception) {
    NSLog(@"Unnecessary KVO observer removal in dealloc");
  }
}

#pragma mark - Placeholder Image Generation

- (void)generatePlaceholderImage
{
  ASVideoNode *__weak weakSelf = self;
  AVAsset *__weak asset = self.asset;

  [self generatePlaceholderImage:^(UIImage *image) {
    ASPerformBlockOnMainThread(^{
      if (ASAssetIsEqual(weakSelf.asset, asset)) {
        [weakSelf setPlaceholderImage:image];
      }
    });
  }];
}

// TODO: Provide a way to override placeholder image generation. Either by subclassing or delegation.
- (void)generatePlaceholderImage:(void(^)(UIImage *image))completionHandler
{
  ASPerformBlockOnBackgroundThread(^{
    AVAssetImageGenerator *previewImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    previewImageGenerator.appliesPreferredTrackTransform = YES;

    [previewImageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:kCMTimeZero]]
                                                completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
      if (error != nil && result != AVAssetImageGeneratorCancelled) {
        ASMultiplexImageNodeLogError(@"Asset preview image generation failed with error: %@", error);
      }
      completionHandler(image ? [UIImage imageWithCGImage:image] : nil);
    }];
  });
}

- (void)setPlaceholderImage:(UIImage *)image
{
  ASDN::MutexLocker l(_videoLock);

  if (_placeholderImageNode == nil) {
    _placeholderImageNode = [[ASImageNode alloc] init];
    _placeholderImageNode.layerBacked = YES;
    _placeholderImageNode.contentMode = [self contentModeFromVideoGravity:_gravity];
    _placeholderImageNode.frame = self.bounds;

    [self insertSubnode:_placeholderImageNode atIndex:0];
  }

  _placeholderImageNode.image = image;
}

- (UIViewContentMode)contentModeFromVideoGravity:(NSString *)videoGravity
{
  if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
    return UIViewContentModeScaleAspectFit;
  } else if ([videoGravity isEqual:AVLayerVideoGravityResizeAspectFill]) {
    return UIViewContentModeScaleAspectFill;
  } else {
    return UIViewContentModeScaleToFill;
  }
}

@end

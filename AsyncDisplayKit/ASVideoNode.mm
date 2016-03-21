/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASVideoNode.h"
#import "ASDefaultPlayButton.h"

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
  
  dispatch_queue_t _previewQueue;
}

@end

@implementation ASVideoNode

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
    
  _previewQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
  
  self.playButton = [[ASDefaultPlayButton alloc] init];
  
  self.gravity = AVLayerVideoGravityResizeAspect;
  
  [self addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
    
  return self;
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  [super interfaceStateDidChange:newState fromState:oldState];
  
  if (!(newState & ASInterfaceStateVisible)) {
    if (oldState & ASInterfaceStateVisible) {
      if (_shouldBePlaying) {
        [self pause];
        _shouldBePlaying = YES;
      }
      [(UIActivityIndicatorView *)_spinner.view stopAnimating];
      [_spinner removeFromSupernode];
    }
  } else {
    if (_shouldBePlaying) {
      [self play];
    }
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([change[@"new"] integerValue] == AVPlayerItemStatusReadyToPlay) {
    if ([self.subnodes containsObject:_spinner]) {
      [_spinner removeFromSupernode];
      _spinner = nil;
    }
  }
  
  if ([change[@"new"] integerValue] == AVPlayerItemStatusFailed) {
    
  }
}

- (void)didPlayToEnd:(NSNotification *)notification
{
  if (ASObjectIsEqual([[notification object] asset], _asset)) {
    if ([_delegate respondsToSelector:@selector(videoPlaybackDidFinish:)]) {
      [_delegate videoPlaybackDidFinish:self];
    }
    [_player seekToTime:CMTimeMakeWithSeconds(0, 1)];
    
    if (_shouldAutorepeat) {
      [self play];
    } else {
      [self pause];
    }
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

  if (_shouldBePlaying) {
    _playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
      AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
      if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:[[AVPlayerItem alloc] initWithAsset:_asset]];
        _player.muted = _muted;
      }
      playerLayer.player = _player;
      playerLayer.videoGravity = [self gravity];
      return playerLayer;
    }];
    
    [self insertSubnode:_playerNode atIndex:0];
  } else {
    dispatch_async(_previewQueue, ^{
      AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_asset];
      imageGenerator.appliesPreferredTrackTransform = YES;
      [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:CMTimeMake(0, 1)]] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        UIImage *theImage = [UIImage imageWithCGImage:image];
        
        _placeholderImageNode = [[ASImageNode alloc] init];
        _placeholderImageNode.layerBacked = YES;
        _placeholderImageNode.image = theImage;
        
        if ([_gravity isEqualToString:AVLayerVideoGravityResize]) {
          _placeholderImageNode.contentMode = UIViewContentModeRedraw;
        }
        if ([_gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
          _placeholderImageNode.contentMode = UIViewContentModeScaleAspectFit;
        }
        if ([_gravity isEqual:AVLayerVideoGravityResizeAspectFill]) {
          _placeholderImageNode.contentMode = UIViewContentModeScaleAspectFill;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
          _placeholderImageNode.frame = self.bounds;
          [self insertSubnode:_placeholderImageNode atIndex:0];
        });
      }];
    });
  }
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

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)fetchData
{
  [super fetchData];

  @try {
    [_currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
  }
  @catch (NSException * __unused exception) {
    NSLog(@"unnecessary removal in fetch data");
  }

  {
    ASDN::MutexLocker l(_videoLock);
    _currentItem = [[AVPlayerItem alloc] initWithAsset:_asset];
    [_currentItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];

    if (_player) {
      [_player replaceCurrentItemWithPlayerItem:_currentItem];
    } else {
      _player = [[AVPlayer alloc] initWithPlayerItem:_currentItem];
      _player.muted = _muted;
    }
  }
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  
  {
    ASDN::MutexLocker l(_videoLock);
    ((AVPlayerLayer *)_playerNode.layer).player = nil;
    _player = nil;
  }
}

- (void)visibilityDidChange:(BOOL)isVisible
{
  [super visibilityDidChange:isVisible];
  
  ASDN::MutexLocker l(_videoLock);
  
  if (_shouldAutoplay && _playerNode.isNodeLoaded) {
    [self play];
  } else if (_shouldAutoplay) {
    _shouldBePlaying = YES;
  }
  if (isVisible) {
    if (_playerNode.isNodeLoaded) {
      if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:[[AVPlayerItem alloc] initWithAsset:_asset]];
        _player.muted = _muted;
      }
      ((AVPlayerLayer *)_playerNode.layer).player = _player;
    }
  
    if (_shouldBePlaying) {
      [self play];
    }
  }
}

#pragma mark - Video Properties

- (void)setPlayButton:(ASButtonNode *)playButton
{
  ASDN::MutexLocker l(_videoLock);
  
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
  
  if (ASObjectIsEqual(asset, _asset)
    || ([asset isKindOfClass:[AVURLAsset class]]
      && [_asset isKindOfClass:[AVURLAsset class]]
      && ASObjectIsEqual(((AVURLAsset *)asset).URL, ((AVURLAsset *)_asset).URL))) {
    return;
  }
  
  _asset = asset;
  
  // FIXME: Adopt -setNeedsFetchData when it is available
  if (self.interfaceState & ASInterfaceStateFetchData) {
    [self fetchData];
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

- (void)setGravity:(NSString *)gravity
{
  ASDN::MutexLocker l(_videoLock);
  if (_playerNode.isNodeLoaded) {
    ((AVPlayerLayer *)_playerNode.layer).videoGravity = gravity;
  }
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

  _muted = muted;
}

#pragma mark - Video Playback

- (void)play
{
  ASDN::MutexLocker l(_videoLock);
  
  if (!_spinner) {
    _spinner = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      UIActivityIndicatorView *spinnnerView = [[UIActivityIndicatorView alloc] init];
      spinnnerView.color = [UIColor whiteColor];
      
      return spinnnerView;
    }];
  }
  
  if (!_playerNode) {
    _playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
      AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
      if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:[[AVPlayerItem alloc] initWithAsset:_asset]];
        _player.muted = _muted;
      }
      playerLayer.player = _player;
      playerLayer.videoGravity = [self gravity];
      return playerLayer;
    }];
    
    if ([self.subnodes containsObject:_playButton]) {
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
  
  if (![self ready] && _shouldBePlaying && (self.interfaceState & ASInterfaceStateVisible)) {
    [self addSubnode:_spinner];
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

#pragma mark - Property Accessors for Tests

- (ASDisplayNode *)spinner
{
  ASDN::MutexLocker l(_videoLock);
  return _spinner;
}

- (AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_videoLock);
  return _currentItem;
}

- (void)setCurrentItem:(AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_videoLock);
  _currentItem = currentItem;
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
  [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
  @try {
    [_currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
  }
  @catch (NSException * __unused exception) {
    NSLog(@"unnecessary removal in dealloc");
  }
}

@end

/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASVideoNode.h"

@interface ASVideoNode ()
{
  ASDN::RecursiveMutex _lock;
  
  __weak id<ASVideoNodeDelegate> _delegate;

  BOOL _shouldBePlaying;
  
  BOOL _shouldAutorepeat;
  BOOL _shouldAutoplay;

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
  
#if DEBUG
  NSLog(@"*** Warning: ASVideoNode is a new component - the 1.9.6 version may cause performance hiccups.");
#endif
  
  self.gravity = AVLayerVideoGravityResizeAspect;
  
  [self addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
    
  return self;
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
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
  if ([[change objectForKey:@"new"] integerValue] == AVPlayerItemStatusReadyToPlay) {
    if ([self.subnodes containsObject:_spinner]) {
      [_spinner removeFromSupernode];
      _spinner = nil;
    }
  }
  
  if ([[change objectForKey:@"new"] integerValue] == AVPlayerItemStatusFailed) {
    
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
      }
      playerLayer.player = _player;
      playerLayer.videoGravity = [self gravity];
      return playerLayer;
    }];
    
    [self insertSubnode:_playerNode atIndex:0];
  } else {
    dispatch_async(_previewQueue, ^{
      AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_asset];
      [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:CMTimeMake(0, 1)]] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        UIImage *theImage = [UIImage imageWithCGImage:image];
        
        _placeholderImageNode = [[ASImageNode alloc] init];
        _placeholderImageNode.layerBacked = YES;
        _placeholderImageNode.image = theImage;
        _placeholderImageNode.contentMode = UIViewContentModeScaleAspectFit;
        
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
  if (_shouldBePlaying) {
    [self pause];
  } else {
    [self play];
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
    ASDN::MutexLocker l(_lock);
    _currentItem = [[AVPlayerItem alloc] initWithAsset:_asset];
    [_currentItem addObserver:self forKeyPath:NSStringFromSelector(@selector(status)) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:NULL];

    if (_player) {
      [_player replaceCurrentItemWithPlayerItem:_currentItem];
    } else {
      _player = [[AVPlayer alloc] initWithPlayerItem:_currentItem];
    }
  }
}


- (void)clearFetchedData
{
  [super clearFetchedData];
  
  {
    ASDN::MutexLocker l(_lock);
    ((AVPlayerLayer *)_playerNode.layer).player = nil;
    _player = nil;
  }
}

- (void)visibilityDidChange:(BOOL)isVisible
{
  ASDN::MutexLocker l(_lock);
  
  if (_shouldAutoplay && _playerNode.isNodeLoaded) {
    [self play];
  }
  if (isVisible) {
    if (_playerNode.isNodeLoaded) {
      if (!_player) {
        _player = [AVPlayer playerWithPlayerItem:[[AVPlayerItem alloc] initWithAsset:_asset]];
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
  ASDN::MutexLocker l(_lock);
  
  _playButton = playButton;
  
  [self addSubnode:playButton];
  
  [_playButton addTarget:self action:@selector(play) forControlEvents:ASControlNodeEventTouchUpInside];
}

- (ASButtonNode *)playButton
{
  ASDN::MutexLocker l(_lock);
  
  return _playButton;
}

- (void)setAsset:(AVAsset *)asset
{
  ASDN::MutexLocker l(_lock);
  
  if (ASObjectIsEqual(((AVURLAsset *)asset).URL, ((AVURLAsset *)_asset).URL)) {
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
  ASDN::MutexLocker l(_lock);
  return _asset;
}

- (AVPlayer *)player
{
  ASDN::MutexLocker l(_lock);
  return _player;
}

- (void)setGravity:(NSString *)gravity
{
  ASDN::MutexLocker l(_lock);
  if (_playerNode.isNodeLoaded) {
    ((AVPlayerLayer *)_playerNode.layer).videoGravity = gravity;
  }
  _gravity = gravity;
}

- (NSString *)gravity
{
  ASDN::MutexLocker l(_lock);
  
  return _gravity;
}

#pragma mark - Video Playback

- (void)play
{
  ASDN::MutexLocker l(_lock);
  
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
      }
      playerLayer.player = _player;
      playerLayer.videoGravity = [self gravity];
      return playerLayer;
    }];
    
    [self addSubnode:_playerNode];
  }
  
  [_player play];
  _shouldBePlaying = YES;
  _playButton.alpha = 0.0;
  
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
  ASDN::MutexLocker l(_lock);
  
  [_player pause];
  [((UIActivityIndicatorView *)_spinner.view) stopAnimating];
  _shouldBePlaying = NO;
  _playButton.alpha = 1.0;
}

- (BOOL)isPlaying
{
  ASDN::MutexLocker l(_lock);
  
  return (_player.rate > 0 && !_player.error);
}

#pragma mark - Property Accessors for Tests

- (ASDisplayNode *)spinner
{
  ASDN::MutexLocker l(_lock);
  return _spinner;
}

- (AVPlayerItem *)curentItem
{
  ASDN::MutexLocker l(_lock);
  return _currentItem;
}

- (void)setCurrentItem:(AVPlayerItem *)currentItem
{
  ASDN::MutexLocker l(_lock);
  _currentItem = currentItem;
}

- (ASDisplayNode *)playerNode
{
  ASDN::MutexLocker l(_lock);
  return _playerNode;
}

- (BOOL)shouldBePlaying
{
  ASDN::MutexLocker l(_lock);
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

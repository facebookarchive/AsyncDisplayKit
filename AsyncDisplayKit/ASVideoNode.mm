

#import "ASVideoNode.h"

@interface ASVideoNode ()
{
  ASDN::RecursiveMutex _lock;
  
  __weak id<ASVideoNodeDelegate> _delegate;

  BOOL _shouldBePlaying;
  AVAsset *_asset;
  
  AVPlayerItem *_currentItem;
  AVPlayer *_player;
  
  ASButtonNode *_playButton;
  ASDisplayNode *_playerNode;
  ASDisplayNode *_spinner;
  ASVideoGravity _gravity;
}

@end

@interface ASDisplayNode ()
- (void)setInterfaceState:(ASInterfaceState)newState;
@end

@implementation ASVideoNode

- (instancetype)init
{
  if (!(self = [super init])) { return nil; }
  
  self.gravity = ASVideoGravityResizeAspect;
  
  [self addTarget:self action:@selector(tapped) forControlEvents:ASControlNodeEventTouchUpInside];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
  
  return self;
}

// FIXME: Adopt interfaceStateDidChange API
- (void)setInterfaceState:(ASInterfaceState)newState
{
  [super setInterfaceState:newState];
  
  if (!(newState & ASInterfaceStateVisible)) {
    [self pause];
    [(UIActivityIndicatorView *)_spinner.view stopAnimating];
    [_spinner removeFromSupernode];
  } else {
    if (_shouldBePlaying) {
      [self play];
    }
  }

  if (newState & ASInterfaceStateVisible) {
    [self displayDidFinish];
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
    [_delegate videoDidReachEnd:self];
    [_player seekToTime:CMTimeMakeWithSeconds(0, 1)];
    
    if (_autorepeat) {
      [self play];
    } else {
      [self pause];
    }
  }
}

- (void)layout
{
  [super layout];
  _playerNode.frame = self.bounds;
  
  CGFloat horizontalDiff = (self.bounds.size.width - _playButton.bounds.size.width)/2;
  CGFloat verticalDiff = (self.bounds.size.height - _playButton.bounds.size.height)/2;
  _playButton.hitTestSlop = UIEdgeInsetsMake(-verticalDiff, -horizontalDiff, -verticalDiff, -horizontalDiff);
  
  _spinner.frame = _playButton.frame;
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

// FIXME: Adopt interfaceStateDidChange API
- (void)displayDidFinish
{
  [super displayDidFinish];
  
  ASDN::MutexLocker l(_lock);
  
  _playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
    AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
    playerLayer.player = _player;
    playerLayer.videoGravity = [self videoGravity];
    return playerLayer;
  }];
  
  [self insertSubnode:_playerNode atIndex:0];

  if (_shouldAutoplay) {
    [self play];
  }
}

- (NSString *)videoGravity
{
  if (_gravity == ASVideoGravityResize) {
    return AVLayerVideoGravityResize;
  }
  if (_gravity == ASVideoGravityResizeAspectFill) {
    return AVLayerVideoGravityResizeAspectFill;
  }
  
  return AVLayerVideoGravityResizeAspect;
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  
  {
    ASDN::MutexLocker l(_lock);
    ((AVPlayerLayer *)_playerNode.layer).player = nil;
    _player = nil;
    _shouldBePlaying = NO;
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

- (void)setGravity:(ASVideoGravity)gravity
{
  ASDN::MutexLocker l(_lock);
  
  switch (gravity) {
    case ASVideoGravityResize:
      ((AVPlayerLayer *)_playerNode.layer).videoGravity = AVLayerVideoGravityResize;
      break;
    case ASVideoGravityResizeAspect:
      ((AVPlayerLayer *)_playerNode.layer).videoGravity = AVLayerVideoGravityResizeAspect;
      break;
    case ASVideoGravityResizeAspectFill:
      ((AVPlayerLayer *)_playerNode.layer).videoGravity = AVLayerVideoGravityResizeAspectFill;
      break;
    default:
      ((AVPlayerLayer *)_playerNode.layer).videoGravity = AVLayerVideoGravityResizeAspect;
      break;
  }
  
  _gravity = gravity;
}

- (ASVideoGravity)gravity
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
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  @try {
    [_currentItem removeObserver:self forKeyPath:NSStringFromSelector(@selector(status))];
  }
  @catch (NSException * __unused exception) {
    NSLog(@"unnecessary removal in dealloc");
  }
}

@end


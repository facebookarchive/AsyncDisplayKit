

#import "ASVideoNode.h"

@interface ASVideoNode ()
{
  ASDN::RecursiveMutex _lock;
  
  __weak id<ASVideoNodeDataSource> _dataSource;
  
  BOOL _shouldBePlaying;
  AVAsset *_asset;
  AVPlayerItem *_currentItem;
  ASButtonNode *_playButton;
  ASDisplayNode *_playerNode;
  ASDisplayNode *_spinner;
}

@end

@interface ASDisplayNode ()
- (void)setInterfaceState:(ASInterfaceState)newState;
@end

@implementation ASVideoNode

- (instancetype)init
{
  if (!(self = [super init])) { return nil; }
  
  _playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
    AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
    playerLayer.player = [[AVPlayer alloc] init];
    return playerLayer;
  }];
  [self addSubnode:_playerNode];
  
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
    [_spinner removeFromSupernode];
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
    [[((AVPlayerLayer *)_playerNode.layer) player] seekToTime:CMTimeMakeWithSeconds(0, 1)];
    
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

    if (((AVPlayerLayer *)_playerNode.layer).player) {
      [((AVPlayerLayer *)_playerNode.layer).player replaceCurrentItemWithPlayerItem:_currentItem];
    } else {
      ((AVPlayerLayer *)_playerNode.layer).player = [[AVPlayer alloc] initWithPlayerItem:_currentItem];
    }

  }
  if (_shouldAutoplay) {
    [self play];
  }
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  
  {
    ASDN::MutexLocker l(_lock);
    ((AVPlayerLayer *)_playerNode.layer).player = nil;
    _shouldBePlaying = NO;
  }
}

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
  
  if (self.interfaceState & ASInterfaceStateFetchData) {
    [self fetchData];
  }
}

- (AVAsset *)asset
{
  ASDN::MutexLocker l(_lock);
  return _asset;
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
}

- (ASVideoGravity)gravity
{
  ASDN::MutexLocker l(_lock);
  
  if (ASObjectIsEqual(((AVPlayerLayer *)_playerNode.layer).contentsGravity, AVLayerVideoGravityResize)) {
    return ASVideoGravityResize;
  }
  if (ASObjectIsEqual(((AVPlayerLayer *)_playerNode.layer).contentsGravity, AVLayerVideoGravityResizeAspectFill)) {
    return ASVideoGravityResizeAspectFill;
  }
  
  return ASVideoGravityResizeAspect;
}

- (void)play
{
  ASDN::MutexLocker l(_lock);
  
  if (!_spinner) {
    _spinner = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      UIActivityIndicatorView *spinnnerView = [[UIActivityIndicatorView alloc] initWithFrame:_playButton.frame];
      spinnnerView.color = [UIColor whiteColor];
      [spinnnerView startAnimating];
      
      return spinnnerView;
    }];
  }
  
  if (![self ready]) {
    [self addSubnode:_spinner];
  }
  
  [[((AVPlayerLayer *)_playerNode.layer) player] play];
  _shouldBePlaying = YES;
  _playButton.alpha = 0.0;
//  if ([self ready] && ![self.subnodes containsObject:_spinner]) {
//  }
}

- (BOOL)ready
{
  return [((AVPlayerLayer *)_playerNode.layer) player].currentItem.status == AVPlayerItemStatusReadyToPlay;
}

- (void)pause
{
  ASDN::MutexLocker l(_lock);
  
  [[((AVPlayerLayer *)_playerNode.layer) player] pause];
  [((UIActivityIndicatorView *)_spinner.view) stopAnimating];
  _shouldBePlaying = NO;
  _playButton.alpha = 1.0;
}

- (AVPlayerItem *)currentItem
{
  return _currentItem;
}

- (ASDisplayNode *)spinner
{
  return _spinner;
}

- (AVPlayerItem *)curentItem
{
  return _currentItem;
}

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


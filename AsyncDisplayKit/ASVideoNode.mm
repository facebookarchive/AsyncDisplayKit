

#import "ASVideoNode.h"

@interface ASVideoNode () {
  ASDN::RecursiveMutex _lock;
  
  __weak id<ASVideoNodeDatasource> _datasource;
  
  AVPlayer *_player;
  BOOL _shouldBePlaying;
  AVAsset *_asset;
  ASButtonNode *_playButton;
  ASDisplayNode *_playerNode;
}

@end

@implementation ASVideoNode

- (instancetype)init {
  if (!(self = [super init])) { return nil; }
  
  _playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{ return [[AVPlayerLayer alloc] init]; }];
  [self addSubnode:_playerNode];
  
  self.gravity = ASVideoGravityResizeAspect;
  
  return self;
}

- (void)layoutDidFinish
{
  _playerNode.frame = self.bounds;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)fetchData
{
  [super fetchData];
  
  {
    ASDN::MutexLocker l(_lock);
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithAsset:_asset];
    ((AVPlayerLayer *)_playerNode.layer).player = [[AVPlayer alloc] initWithPlayerItem:item];
    if (_shouldBePlaying) {
        [[((AVPlayerLayer *)_playerNode.layer) player] play];
    }
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
  [self.view bringSubviewToFront:playButton.view];
  
  [_playButton addTarget:self action:@selector(playButtonWasTouchedUpInside) forControlEvents:ASControlNodeEventTouchUpInside];
}

- (void)playButtonWasTouchedUpInside
{
  [self play];
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
  return _asset;
}

- (void)setGravity:(ASVideoGravity)gravity {
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

- (ASVideoGravity)gravity;
{
  ASDN::MutexLocker l(_lock);

  if ([((AVPlayerLayer *)_playerNode.layer).contentsGravity isEqualToString:AVLayerVideoGravityResize]) {
    return ASVideoGravityResize;
  }
  if ([((AVPlayerLayer *)_playerNode.layer).contentsGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    return ASVideoGravityResizeAspectFill;
  }
  
  return ASVideoGravityResizeAspect;
}

- (void)play;
{
  ASDN::MutexLocker l(_lock);

  [[((AVPlayerLayer *)_playerNode.layer) player] play];
  _shouldBePlaying = YES;
}

- (void)pause;
{
  ASDN::MutexLocker l(_lock);

  [[((AVPlayerLayer *)_playerNode.layer) player] pause];
  _shouldBePlaying = NO;
}

@end

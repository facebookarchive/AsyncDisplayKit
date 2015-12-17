

#import "ASVideoNode.h"

@interface ASVideoNode ()
@property (nonatomic) AVPlayer *player;
@end

@implementation ASVideoNode

- (instancetype)initWithURL:(NSURL *)URL;
{
  return [self initWithURL:URL videoGravity:ASVideoGravityResizeAspect];
}

- (instancetype)initWithURL:(NSURL *)URL videoGravity:(ASVideoGravity)gravity;
{
  if (!(self = [super initWithLayerBlock:^CALayer *{
    AVPlayerLayer *layer = [[AVPlayerLayer alloc] init];
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:URL];
    
    layer.player = [[AVPlayer alloc] initWithPlayerItem:item];
    
    return layer;
  }])) { return nil; }
  
  self.gravity = gravity;
  
  return self;
}

- (void)setGravity:(ASVideoGravity)gravity;
{
  switch (gravity) {
    case ASVideoGravityResize:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResize;
      break;
    case ASVideoGravityResizeAspect:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspect;
      break;
    case ASVideoGravityResizeAspectFill:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspectFill;
      break;
    default:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspect;
      break;
  }
}

- (ASVideoGravity)gravity;
{
  if ([((AVPlayerLayer *)self.layer).contentsGravity isEqualToString:AVLayerVideoGravityResize]) {
    return ASVideoGravityResize;
  }
  if ([((AVPlayerLayer *)self.layer).contentsGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    return ASVideoGravityResizeAspectFill;
  }
  
  return ASVideoGravityResizeAspect;
}

- (void)play;
{
  [[((AVPlayerLayer *)self.layer) player] play];
}

- (void)pause;
{
  [[((AVPlayerLayer *)self.layer) player] pause];
}

@end

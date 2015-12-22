
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSUInteger, ASVideoGravity) {
  ASVideoGravityResizeAspect,
  ASVideoGravityResizeAspectFill,
  ASVideoGravityResize
};

@protocol ASVideoNodeDelegate;

@interface ASVideoNode : ASControlNode<_ASDisplayLayerDelegate>
@property (atomic, strong, readwrite) AVAsset *asset;
@property (atomic, strong, readonly) AVPlayer *player;
@property (atomic, strong, readonly) AVPlayerItem *currentItem;
@property (nonatomic, assign, readwrite) BOOL shouldAutoplay;
@property (atomic) ASVideoGravity gravity;
@property (atomic) BOOL autorepeat;
@property (atomic) ASButtonNode *playButton;

@property (atomic, weak, readwrite) id<ASVideoNodeDelegate> delegate;

- (void)play;
- (void)pause;

- (BOOL)isPlaying;

@end

@protocol ASVideoNodeDelegate <NSObject>
@optional
- (void)videoDidReachEnd:(ASVideoNode *)videoNode;
@end


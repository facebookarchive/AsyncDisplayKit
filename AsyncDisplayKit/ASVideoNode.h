
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSUInteger, ASVideoGravity) {
  ASVideoGravityResizeAspect,
  ASVideoGravityResizeAspectFill,
  ASVideoGravityResize
};

@protocol ASVideoNodeDelegate;

@interface ASVideoNode : ASControlNode
@property (atomic, strong, readwrite) AVAsset *asset;
@property (atomic, strong, readonly) AVPlayer *player;
@property (atomic, strong, readonly) AVPlayerItem *currentItem;

// When autoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
// If it leaves the visible interfaceState it will pause but will resume once it has returned
@property (nonatomic, assign, readwrite) BOOL shouldAutoplay;
@property (nonatomic, assign, readwrite) BOOL shouldAutorepeat;

@property (atomic) NSString *gravity;
@property (atomic) ASButtonNode *playButton;

@property (atomic, weak, readwrite) id<ASVideoNodeDelegate> delegate;

- (void)play;
- (void)pause;

- (BOOL)isPlaying;

@end

@protocol ASVideoNodeDelegate <NSObject>
@optional
- (void)videoPlaybackDidFinish:(ASVideoNode *)videoNode;
@end


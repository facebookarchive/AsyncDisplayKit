
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSUInteger, ASVideoGravity) {
  ASVideoGravityResizeAspect,
  ASVideoGravityResizeAspectFill,
  ASVideoGravityResize
};

@interface ASVideoNode : ASControlNode<_ASDisplayLayerDelegate>
@property (atomic, strong, readwrite) AVAsset *asset;
@property (nonatomic, assign, readwrite) BOOL shouldAutoplay;
@property (atomic) ASVideoGravity gravity;
@property (atomic) BOOL autorepeat;
@property (atomic) ASButtonNode *playButton;
@property (atomic) AVPlayer *player;

- (void)play;
- (void)pause;

@end

@protocol ASVideoNodeDelegate <NSObject>
@end

@protocol ASVideoNodeDataSource <NSObject>
@optional
- (ASButtonNode *)playButtonForVideoNode:(ASVideoNode *)videoNode;
- (UIImage *)thumbnailForVideoNode:(ASVideoNode *) videoNode;
- (NSURL *)thumbnailURLForVideoNode:(ASVideoNode *)videoNode;
@end

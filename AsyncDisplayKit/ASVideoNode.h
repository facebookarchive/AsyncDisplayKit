
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSUInteger, ASVideoGravity) {
  ASVideoGravityResizeAspect,
  ASVideoGravityResizeAspectFill,
  ASVideoGravityResize
};

@interface ASVideoNode : ASDisplayNode<_ASDisplayLayerDelegate>
@property (atomic, strong, readwrite) AVAsset *asset;
@property (nonatomic, assign, readwrite) BOOL shouldAutoPlay;
@property (atomic) ASVideoGravity gravity;
@property (atomic) BOOL autorepeat;
@property (atomic) ASButtonNode *playButton;

- (void)play;
- (void)pause;

@end

@protocol ASVideoNodeDelegate <NSObject>
@end

@protocol ASVideoNodeDatasource <NSObject>
@optional
- (ASDisplayNode *)playButtonForVideoNode:(ASVideoNode *) videoNode;
- (UIImage *)thumbnailForVideoNode:(ASVideoNode *) videoNode;
- (NSURL *)thumbnailURLForVideoNode:(ASVideoNode *)videoNode;
@end

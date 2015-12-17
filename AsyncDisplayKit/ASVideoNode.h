
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSUInteger, ASVideoGravity) {
  ASVideoGravityResizeAspect,
  ASVideoGravityResizeAspectFill,
  ASVideoGravityResize
};

// set up boolean to repeat video
// set up delegate methods to provide play button
// tapping should play and pause

@interface ASVideoNode : ASDisplayNode
@property (atomic, strong, readwrite) AVAsset *asset;
@property (nonatomic, assign, readwrite) BOOL shouldRepeat;
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

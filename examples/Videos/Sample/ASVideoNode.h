
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
@property (nonatomic) NSURL *URL;
@property (nonatomic) BOOL shouldRepeat;
@property (nonatomic) ASVideoGravity gravity;

- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithURL:(NSURL *)URL videoGravity:(ASVideoGravity)gravity;

- (void)play;
- (void)pause;

@end

@protocol ASVideoNodeDelegate <NSObject>

@end

//
//  ASImageNode+AnimatedImage.h
//  Pods
//
//  Created by Garrett Moon on 3/22/16.
//
//

#import "ASImageNode.h"

#import "ASThread.h"

@interface ASImageNode ()
{
  ASDN::RecursiveMutex _animatedImageLock;
  ASDN::Mutex _displayLinkLock;
  ASAnimatedImage *_animatedImage;
  CADisplayLink *_displayLink;
  
  //accessed on main thread only
  CFTimeInterval _playHead;
  NSUInteger _playedLoops;
}

@property (atomic, assign) BOOL animatedImagePaused;
@property (atomic, assign) CFTimeInterval lastDisplayLinkFire;

@end

@interface ASImageNode (AnimatedImage)

@property (nullable, atomic, strong) ASAnimatedImage *animatedImage;

- (void)coverImageCompleted:(UIImage *)coverImage;

@end

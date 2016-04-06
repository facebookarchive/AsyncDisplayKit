//
//  ASImageNode+AnimatedImagePrivate.h
//  Pods
//
//  Created by Garrett Moon on 3/30/16.
//
//

@interface ASImageNode ()
{
  ASDN::RecursiveMutex _animatedImageLock;
  ASDN::Mutex _displayLinkLock;
  id <ASAnimatedImageProtocol> _animatedImage;
  CADisplayLink *_displayLink;
  
  //accessed on main thread only
  CFTimeInterval _playHead;
  NSUInteger _playedLoops;
}

@property (atomic, assign) CFTimeInterval lastDisplayLinkFire;

@end

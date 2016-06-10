//
//  ASImageNode+AnimatedImagePrivate.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/30/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASThread.h"

extern NSString *const ASAnimatedImageDefaultRunLoopMode;

@interface ASImageNode ()
{
  ASDN::RecursiveMutex _animatedImageLock;
  ASDN::Mutex _displayLinkLock;
  id <ASAnimatedImageProtocol> _animatedImage;
  BOOL _animatedImagePaused;
  NSString *_animatedImageRunLoopMode;
  CADisplayLink *_displayLink;
  
  //accessed on main thread only
  CFTimeInterval _playHead;
  NSUInteger _playedLoops;
}

@property (atomic, assign) CFTimeInterval lastDisplayLinkFire;

@end

//
//  ASImageNode+AnimatedImagePrivate.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/30/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASThread.h>

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

@property (nonatomic, assign) CFTimeInterval lastDisplayLinkFire;

@end

@interface ASImageNode (AnimatedImagePrivate)

- (void)_locked_setAnimatedImage:(id <ASAnimatedImageProtocol>)animatedImage;

@end


@interface ASImageNode (AnimatedImageInvalidation)

- (void)invalidateAnimatedImage;

@end

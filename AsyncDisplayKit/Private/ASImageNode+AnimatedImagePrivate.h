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

#import "ASThread.h"

@interface ASImageNode ()
{
  ASDN::RecursiveMutex _animatedImageLock;
  ASDN::Mutex _displayLinkLock;
  id <ASAnimatedImageProtocol> _animatedImage;
  BOOL _animatedImagePaused;
  CADisplayLink *_displayLink;
  
  //accessed on main thread only
  CFTimeInterval _playHead;
  NSUInteger _playedLoops;
}

@property (atomic, assign) CFTimeInterval lastDisplayLinkFire;

@end

//
//  AsyncDisplayKit+Debug.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AsyncDisplayKit+Debug.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASTextNode.h"

static BOOL __enableImageSizeOverlay = NO;

@implementation ASImageNode (Debug)

+ (void)setImageDebugEnabled:(BOOL)enable;
{
  __enableImageSizeOverlay = enable;
}

+ (BOOL)shouldShowImageDebugOverlay
{
  return __enableImageSizeOverlay;
}

@end

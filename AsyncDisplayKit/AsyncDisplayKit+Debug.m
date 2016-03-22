//
//  AsyncDisplayKit+Debug.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AsyncDisplayKit+Debug.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNode+FrameworkPrivate.h"

static BOOL __shouldShowImageScalingOverlay = NO;

@implementation ASDisplayNode (LayoutDebugging)

- (void)shouldVisualizeLayoutSpecs:(BOOL)visualize
{
  if (visualize) {
    [self enterHierarchyState:ASHierarchyStateVisualizeLayoutSpecs];
  } else {
    [self exitHierarchyState:ASHierarchyStateVisualizeLayoutSpecs];
  }
  [self setNeedsLayout];
}

@end

@implementation ASImageNode (Debugging)

+ (void)setShouldShowImageScalingOverlay:(BOOL)show;
{
  __shouldShowImageScalingOverlay = show;
}

+ (BOOL)shouldShowImageScalingOverlay
{
  return __shouldShowImageScalingOverlay;
}

@end

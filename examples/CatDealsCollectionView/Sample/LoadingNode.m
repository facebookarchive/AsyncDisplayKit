//
//  LoadingNode.m
//  AsyncDisplayKit
//
//  Created by Samuel Stow on 1/9/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "LoadingNode.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASHighlightOverlayLayer.h>

#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutSpec.h>

static CGFloat kFixedHeight = 200.0f;

@interface LoadingNode ()
{
  ASDisplayNode *_loadingSpinner;
}

@end

@implementation LoadingNode


#pragma mark -
#pragma mark ASCellNode.

+ (CGFloat)desiredHeightForWidth:(CGFloat)width {
  return kFixedHeight;
}

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  _loadingSpinner = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull{
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    return spinner;
  }];
  _loadingSpinner.preferredFrameSize = CGSizeMake(50, 50);
  
  
  // add it as a subnode, and we're done
  [self addSubnode:_loadingSpinner];
  
  return self;
}

- (void)layout {
  [super layout];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASCenterLayoutSpec *centerSpec = [[ASCenterLayoutSpec alloc] init];
  centerSpec.centeringOptions = ASCenterLayoutSpecCenteringXY;
  centerSpec.sizingOptions = ASCenterLayoutSpecSizingOptionDefault;
  centerSpec.child = _loadingSpinner;
  
  return centerSpec;
}

@end

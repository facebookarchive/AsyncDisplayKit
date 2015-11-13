/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASVisualEffectNode.h"

#import "ASThread.h"

@interface ASVisualEffectNode ()
{
  ASDN::RecursiveMutex _propertyLock;
}
@end

@implementation ASVisualEffectNode

+ (instancetype)blurNodeWithEffect:(UIBlurEffectStyle)effectStyle
{
  UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:effectStyle];
  return [[self alloc] initWithEffect:blurEffect];
}

- (instancetype)initWithEffect:(UIVisualEffect*)visualEffect
{
  return [self initWithViewBlock:^UIView *{
    _visualEffectView = [[UIVisualEffectView alloc] initWithEffect:visualEffect];
    _visualEffectView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    return _visualEffectView;
  }];
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  // ASRangeController expects ASVisualEffectNode to be view-backed.  (Layer-backing is supported on ASCellNode subnodes.)
  ASDisplayNodeAssert(!layerBacked, @"ASVisualEffectNode does not support layer-backing.");
}

- (UIView *)parentViewForSubnodeViews
{
  ASDN::MutexLocker l(_propertyLock);
  return self.visualEffectView.contentView;
}

@end

//
//  ASScrollNode.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASScrollNode.h"
#import "ASDisplayNodeInternal.h" // TODO: This can be removed after __instanceLock__ cleanup lands
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASLayout.h"
#import "_ASDisplayLayer.h"

@interface ASScrollView : UIScrollView
@end

@implementation ASScrollView

// This special +layerClass allows ASScrollNode to get -layout calls from -layoutSublayers.
+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

@end

@implementation ASScrollNode
{
  CGSize _contentCalculatedSizeFromLayout;
}
@dynamic view;

- (instancetype)init
{
  return [super initWithViewBlock:^UIView *{ return [[ASScrollView alloc] init]; }];
}

- (void)layout
{
  [super layout];
  ASDN::MutexLocker l(__instanceLock__);
  if (_automaticallyManagesContentSize) {
    CGSize contentSize = _contentCalculatedSizeFromLayout;
    if (ASIsCGSizeValidForLayout(contentSize) == NO) {
      NSLog(@"%@ calculated a size in its layout spec that can't be applied to .contentSize: %@. Applying CGSizeZero instead.", self, NSStringFromCGSize(contentSize));
      contentSize = CGSizeZero;
    }
    self.view.contentSize = _contentCalculatedSizeFromLayout;
  }
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  ASLayout *layout = [super calculateLayoutThatFits:constrainedSize];
  ASDN::MutexLocker l(__instanceLock__);
  if (_automaticallyManagesContentSize) {
    _contentCalculatedSizeFromLayout = layout.size;
    if (ASIsCGSizeValidForLayout(constrainedSize.max)) {
      layout = [ASLayout layoutWithLayoutElement:self size:constrainedSize.max sublayouts:layout.sublayouts];
    }
  }
  return layout;
}

@end

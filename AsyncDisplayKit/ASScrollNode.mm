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
  BOOL _automaticallyManagesContentSize;
  CGSize _contentCalculatedSizeFromLayout;
}
@dynamic view;

- (instancetype)init
{
  return [super initWithViewBlock:^UIView *{ return [[ASScrollView alloc] init]; }];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  ASLayout *layout = [super calculateLayoutThatFits:constrainedSize
                                   restrictedToSize:size
                               relativeToParentSize:parentSize];
  
  ASDN::MutexLocker l(__instanceLock__);  // Lock for using our two instance variables.
  
  if (_automaticallyManagesContentSize) {
    _contentCalculatedSizeFromLayout = layout.size;
    if (ASIsCGSizeValidForLayout(parentSize)) {
      layout = [ASLayout layoutWithLayoutElement:self
                                            size:parentSize
                                        position:CGPointZero
                                      sublayouts:layout.sublayouts];
    }
  }
  return layout;
}

- (void)layout
{
  [super layout];
  
  ASDN::MutexLocker l(__instanceLock__);  // Lock for using our two instance variables.
  
  if (_automaticallyManagesContentSize) {
    CGSize contentSize = _contentCalculatedSizeFromLayout;
    if (ASIsCGSizeValidForLayout(contentSize) == NO) {
      NSLog(@"%@ calculated a size in its layout spec that can't be applied to .contentSize: %@. Applying parentSize (scrollNode's bounds) instead: %@.", self, NSStringFromCGSize(contentSize), NSStringFromCGSize(self.calculatedSize));
      contentSize = self.calculatedSize;
    }
    self.view.contentSize = contentSize;
  }
}

- (BOOL)automaticallyManagesContentSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return _automaticallyManagesContentSize;
}

- (void)setAutomaticallyManagesContentSize:(BOOL)automaticallyManagesContentSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _automaticallyManagesContentSize = automaticallyManagesContentSize;
}

@end

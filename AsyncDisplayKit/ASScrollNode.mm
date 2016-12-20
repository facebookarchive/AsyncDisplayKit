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
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+FrameworkSubclasses.h"
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

- (ASScrollNode *)scrollNode
{
  return (ASScrollNode *)ASViewToDisplayNode(self);
}

#pragma mark - _ASDisplayView behavior substitutions
// Need these to drive interfaceState so we know when we are visible, if not nested in another range-managing element.
// Because our superclass is a true UIKit class, we cannot also subclass _ASDisplayView.
- (void)willMoveToWindow:(UIWindow *)newWindow
{
  ASDisplayNode *node = self.scrollNode; // Create strong reference to weak ivar.
  BOOL visible = (newWindow != nil);
  if (visible && !node.inHierarchy) {
    [node __enterHierarchy];
  }
}

- (void)didMoveToWindow
{
  ASDisplayNode *node = self.scrollNode; // Create strong reference to weak ivar.
  BOOL visible = (self.window != nil);
  if (!visible && node.inHierarchy) {
    [node __exitHierarchy];
  }
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
    // To understand this code, imagine we're containing a horizontal stack set within a vertical table node.
    // Our parentSize is fixed ~375pt width, but 0 - INF height.  Our stack measures 1000pt width, 50pt height.
    // In this case, we want our scrollNode.bounds to be 375pt wide, and 50pt high.  ContentSize 1000pt, 50pt.
    // We can achieve this behavior by: 1. Always set contentSize to layout.size.  2. Set bounds to parentSize,
    // unless one dimension is not defined, in which case adopt the contentSize for that dimension.
    _contentCalculatedSizeFromLayout = layout.size;
    CGSize selfSize = parentSize;
    if (ASPointsValidForLayout(selfSize.width) == NO) {
      selfSize.width = _contentCalculatedSizeFromLayout.width;
    }
    if (ASPointsValidForLayout(selfSize.height) == NO) {
      selfSize.height = _contentCalculatedSizeFromLayout.height;
    }
    // Don't provide a position, as that should be set by the parent.
    layout = [ASLayout layoutWithLayoutElement:self
                                          size:parentSize
                                    sublayouts:layout.sublayouts];
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

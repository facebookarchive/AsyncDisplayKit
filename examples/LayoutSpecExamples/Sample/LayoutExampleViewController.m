//
//  LayoutExampleViewController.m
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "LayoutExampleViewController.h"
#import "LayoutExampleNodes.h"

@interface LayoutExampleViewController ()
@property (nonatomic, strong) LayoutExampleNode *customNode;
@end

@implementation LayoutExampleViewController

- (instancetype)initWithClass:(Class)class
{
  self = [super initWithNode:[ASDisplayNode new]];
  
  if (self) {
    _customNode = [class new];
    [self.node addSubnode:_customNode];
    
    __weak __typeof(self) weakself = self;
    if ([class isEqual:[HeaderWithRightAndLeftItems class]] || [class isEqual:[FlexibleSeparatorSurroundingContent class]]) {
      self.node.backgroundColor = [UIColor lightGrayColor];
      self.node.layoutSpecBlock = ^ASLayoutSpec*(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
        return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringY
                                                          sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY
                                                                  child:weakself.customNode];
      };
    } else {
      self.node.backgroundColor = [UIColor whiteColor];
      self.node.layoutSpecBlock = ^ASLayoutSpec*(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
        return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY
                                                          sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY
                                                                  child:weakself.customNode];
        };
    };
  }
  
  return self;
}

@end

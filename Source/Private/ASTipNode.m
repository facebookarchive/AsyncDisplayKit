//
//  ASTipNode.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTipNode.h"

#if AS_ENABLE_TIPS

@implementation ASTipNode

- (instancetype)initWithTip:(ASTip *)tip
{
  if (self = [super init]) {
    self.backgroundColor = [UIColor colorWithRed:0 green:0.7 blue:0.2 alpha:0.3];
    _tip = tip;
    [self addTarget:nil action:@selector(didTapTipNode:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  return self;
}

@end

#endif // AS_ENABLE_TIPS

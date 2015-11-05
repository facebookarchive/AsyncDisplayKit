//
//  ASTableNode.m
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASTableNode.h"

@implementation ASTableNode

- (instancetype)initWithStyle:(UITableViewStyle)style
{
  if (self = [super initWithViewBlock:^UIView *{
    return [[ASTableView alloc] initWithFrame:CGRectZero style:style];
  }]) {
    return self;
  }
  return nil;
}

- (ASTableView *)view
{
  return (ASTableView *)[super view];
}

@end

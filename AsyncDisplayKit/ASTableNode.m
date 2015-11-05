//
//  ASTableNode.m
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASTableNode.h"

@implementation ASTableNode

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style asyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  if (self = [super initWithViewBlock:^UIView *{
    return [[ASTableView alloc] initWithFrame:frame style:style asyncDataFetching:asyncDataFetchingEnabled];
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

//
//  PageNode.m
//  Sample
//
//  Created by McCallum, Levi on 12/7/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "PageNode.h"

@implementation PageNode

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutableObject:self size:constrainedSize.max];
}

- (void)fetchData
{
  [super fetchData];
  NSLog(@"Fetching data for node: %@", self);
}

@end

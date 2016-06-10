//
//  PageNode.m
//  AsyncDisplayKit
//
//  Created by McCallum, Levi on 12/7/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "PageNode.h"

@implementation PageNode

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutableObject:self 
                         constrainedSizeRange:constrainedSize
                                         size:constrainedSize.max];
}

- (void)fetchData
{
  [super fetchData];
  NSLog(@"Fetching data for node: %@", self);
}

@end

//
//  SlowpokeTextNode.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "SlowpokeTextNode.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@interface ASTextNode (ForwardWorkaround)
// This is a workaround until subclass overriding of custom drawing class methods is fixed
- (void)drawRect:(CGRect)bounds withParameters:(id<NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing;
@end

@implementation SlowpokeTextNode

- (void)drawRect:(CGRect)bounds withParameters:(id<NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing
{
  usleep( (long)(1.0 * USEC_PER_SEC) ); // artificial delay of 1.0

  [super drawRect:bounds withParameters:parameters isCancelled:isCancelledBlock isRasterizing:isRasterizing];
}

@end

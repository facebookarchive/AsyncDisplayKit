//
//  ASDisplayNodeTestsHelper.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDisplayNodeTestsHelper.h"

#import <QuartzCore/QuartzCore.h>

#import <libkern/OSAtomic.h>

// Poll the condition 1000 times a second.
static CFTimeInterval kSingleRunLoopTimeout = 0.001;

// Time out after 30 seconds.
static CFTimeInterval kTimeoutInterval = 30.0f;

BOOL ASDisplayNodeRunRunLoopUntilBlockIsTrue(as_condition_block_t block)
{
  CFTimeInterval timeoutDate = CACurrentMediaTime() + kTimeoutInterval;
  BOOL passed = NO;
  while (true) {
    OSMemoryBarrier();
    passed = block();
    OSMemoryBarrier();
    if (passed) {
      break;
    }
    CFTimeInterval now = CACurrentMediaTime();
    if (now > timeoutDate) {
      break;
    }
    // Run until the poll timeout or until timeoutDate, whichever is first.
    CFTimeInterval runLoopTimeout = MIN(kSingleRunLoopTimeout, timeoutDate - now);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, runLoopTimeout, true);
  }
  return passed;
}

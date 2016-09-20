//
//  _ASScopeTimer.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

/**
 Must compile as c++ for this to work.

 Usage:
 // Can be an ivar or local variable
 NSTimeInterval placeToStoreTiming;

 {
   // some scope
   ASDisplayNode::ScopeTimer t(placeToStoreTiming);
   DoPotentiallySlowWork();
   MorePotentiallySlowWork();
 }

 */

namespace ASDN {
  struct ScopeTimer {
    NSTimeInterval begin;
    NSTimeInterval &outT;
    ScopeTimer(NSTimeInterval &outRef) : outT(outRef) {
      begin = CACurrentMediaTime();
    }
    ~ScopeTimer() {
      outT = CACurrentMediaTime() - begin;
    }
  };

  // variant where repeated calls are summed
  struct SumScopeTimer {
    NSTimeInterval begin;
    NSTimeInterval &outT;
    BOOL enable;
    SumScopeTimer(NSTimeInterval &outRef, BOOL enable = YES) : outT(outRef), enable(enable) {
      if (enable) {
        begin = CACurrentMediaTime();
      }
    }
    ~SumScopeTimer() {
      if (enable) {
        outT += CACurrentMediaTime() - begin;
      }
    }
  };
}

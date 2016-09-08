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
}

/**
 Must compile as c++ for this to work.

 Usage:
 // Can be an ivar or local variable. Sums a timing measurement with an existing value.
 NSTimeInterval placeToStoreTiming;

 {
 // some scope
 ASDisplayNode::ScopeTimer t(placeToStoreTiming);
 DoPotentiallySlowWork();
 MorePotentiallySlowWork();
 }

 */
namespace ASDN {
  struct ScopeTimerDataPoint {
    NSTimeInterval begin;
    NSTimeInterval &outT;
    ScopeTimerDataPoint(NSTimeInterval &outRef) : outT(outRef) {
      begin = CACurrentMediaTime();
    }
    ~ScopeTimerDataPoint() {
      outT += CACurrentMediaTime() - begin;
    }
  };
}

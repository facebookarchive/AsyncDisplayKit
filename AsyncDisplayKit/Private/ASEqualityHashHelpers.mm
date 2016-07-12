//
//  ASEqualityHashHelpers.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASEqualityHashHelpers.h"

NSUInteger ASIntegerArrayHash(const NSUInteger *subhashes, NSUInteger count)
{
  uint64_t result = subhashes[0];
  for (int ii = 1; ii < count; ++ii) {
    result = ASHashCombine(result, subhashes[ii]);
  }
  return ASHash64ToNative(result);
}


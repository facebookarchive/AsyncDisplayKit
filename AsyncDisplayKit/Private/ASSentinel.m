/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASSentinel.h"

#import <libkern/OSAtomic.h>

@implementation ASSentinel
{
  int32_t _value;
}

- (int32_t)value
{
  return _value;
}

- (int32_t)increment
{
  return OSAtomicIncrement32(&_value);
}

@end

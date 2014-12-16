/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASBaseDefines.h"

/**
 @abstract Correctly equates two objects, including cases where both objects are nil. The latter is a case where `isEqual:` fails.
 @param obj The first object in the comparison. Can be nil.
 @param obj The second object in the comparison. Can be nil.
 @result YES if the objects are equal, including cases where both object are nil.
 */
ASDISPLAYNODE_INLINE BOOL ASObjectIsEqual(id<NSObject> obj, id<NSObject> otherObj)
{
  if (obj == otherObj)
    return YES;
  return [obj isEqual:otherObj];
}

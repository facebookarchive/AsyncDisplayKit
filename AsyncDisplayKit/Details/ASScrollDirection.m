/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASScrollDirection.h"

const ASScrollDirection ASScrollDirectionHorizontalDirections = ASScrollDirectionLeft | ASScrollDirectionRight;
const ASScrollDirection ASScrollDirectionVerticalDirections = ASScrollDirectionUp | ASScrollDirectionDown;

BOOL ASScrollDirectionContainsVerticalDirection(ASScrollDirection scrollDirection) {
  return (scrollDirection & ASScrollDirectionVerticalDirections) != 0;
}

BOOL ASScrollDirectionContainsHorizontalDirection(ASScrollDirection scrollDirection) {
  return (scrollDirection & ASScrollDirectionHorizontalDirections) != 0;
}

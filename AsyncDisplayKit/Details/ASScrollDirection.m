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

BOOL ASScrollDirectionContainsRight(ASScrollDirection scrollDirection) {
  return (scrollDirection & ASScrollDirectionRight) != 0;
}

BOOL ASScrollDirectionContainsLeft(ASScrollDirection scrollDirection) {
  return (scrollDirection & ASScrollDirectionLeft) != 0;
}

BOOL ASScrollDirectionContainsUp(ASScrollDirection scrollDirection) {
  return (scrollDirection & ASScrollDirectionUp) != 0;
}

BOOL ASScrollDirectionContainsDown(ASScrollDirection scrollDirection) {
  return (scrollDirection & ASScrollDirectionDown) != 0;
}

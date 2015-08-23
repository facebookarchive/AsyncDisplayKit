/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASTextNode.h>

/**
 * The subclass header _ASTextNode+Subclasses_ defines methods to be
 * overridden by custom nodes that subclass ASTextNode.
 *
 * These methods should never be called directly by other classes.
 */

@interface ASTextNode (Subclasses)

/**
 @abstract Calculates a size that will fit all of the text in this text node.
 @param constrainedSize The maximum available space to render into
 @discussion The size returned from this method is used to create an ASLayout of the appropriate size.
 */
- (CGSize)renderSizeThatFits:(CGSize)constrainedSize;

@end

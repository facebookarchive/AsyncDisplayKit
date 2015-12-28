/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

@interface ASDisplayNode (Beta)

+ (BOOL)shouldUseNewRenderingRange;
+ (void)setShouldUseNewRenderingRange:(BOOL)shouldUseNewRenderingRange;

/** @name Layout */


/**
 * @abstract Recursively ensures node and all subnodes are displayed.
 * @see Full documentation in ASDisplayNode+FrameworkPrivate.h
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

@end

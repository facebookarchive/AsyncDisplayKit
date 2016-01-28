/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASDisplayLayer.h"

@interface ASDisplayNode (Beta)

+ (BOOL)shouldUseNewRenderingRange;
+ (void)setShouldUseNewRenderingRange:(BOOL)shouldUseNewRenderingRange;

/** @name Layout */


/**
 * @abstract Recursively ensures node and all subnodes are displayed.
 * @see Full documentation in ASDisplayNode+FrameworkPrivate.h
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

- (void)drawRect:(CGRect)bounds withParameters:(id <NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing;

- (UIImage *)displayWithParameters:(id <NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled;

/**
 * @abstract allow modification of a context before the node's content is drawn
 *
 * @discussion Set the block to be called after the context has been created and before the node's content is drawn.
 * You can override this to modify the context before the content is drawn. You are responsible for saving and
 * restoring context if necessary. Restoring can be done in contextDidDisplayNodeContent
 * This block can be called from *any* thread and it is unsafe to access any UIKit main thread properties from it.
 */
@property (nonatomic, strong) ASDisplayNodeContextModifier willDisplayNodeContentBlock;

/**
 * @abstract allow modification of a context after the node's content is drawn
 *
 * @discussion
 */
@property (nonatomic, strong) ASDisplayNodeContextModifier didDisplayNodeContentBlock;

@end

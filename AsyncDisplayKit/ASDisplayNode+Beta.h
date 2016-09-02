//
//  ASDisplayNode+Beta.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDisplayNode.h"
#import "ASLayoutRangeType.h"

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN
void ASPerformBlockOnMainThread(void (^block)());
void ASPerformBlockOnBackgroundThread(void (^block)()); // DISPATCH_QUEUE_PRIORITY_DEFAULT
ASDISPLAYNODE_EXTERN_C_END

@interface ASDisplayNode (Beta)

/**
 * ASTableView and ASCollectionView now throw exceptions on invalid updates
 * like their UIKit counterparts. If YES, these classes will log messages
 * on invalid updates rather than throwing exceptions.
 *
 * Note that even if AsyncDisplayKit's exception is suppressed, the app may still crash
 * as it proceeds with an invalid update.
 *
 * This property defaults to NO. It will be removed in a future release.
 */
+ (BOOL)suppressesInvalidCollectionUpdateExceptions;
+ (void)setSuppressesInvalidCollectionUpdateExceptions:(BOOL)suppresses;

/** @name Layout */


/**
 * @abstract Recursively ensures node and all subnodes are displayed.
 * @see Full documentation in ASDisplayNode+FrameworkPrivate.h
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

/**
 * @abstract allow modification of a context before the node's content is drawn
 *
 * @discussion Set the block to be called after the context has been created and before the node's content is drawn.
 * You can override this to modify the context before the content is drawn. You are responsible for saving and
 * restoring context if necessary. Restoring can be done in contextDidDisplayNodeContent
 * This block can be called from *any* thread and it is unsafe to access any UIKit main thread properties from it.
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;

/**
 * @abstract allow modification of a context after the node's content is drawn
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;

/** @name Layout Transitioning */

/**
 * @abstract Currently used by ASNetworkImageNode and ASMultiplexImageNode to allow their placeholders to stay if they are loading an image from the network.
 * Otherwise, a display pass is scheduled and completes, but does not actually draw anything - and ASDisplayNode considers the element finished.
 */
- (BOOL)placeholderShouldPersist;

/**
 * @abstract Indicates that the receiver and all subnodes have finished displaying. May be called more than once, for example if the receiver has
 * a network image node. This is called after the first display pass even if network image nodes have not downloaded anything (text would be done,
 * and other nodes that are ready to do their final display). Each render of every progressive jpeg network node would cause this to be called, so
 * this hook could be called up to 1 + (pJPEGcount * pJPEGrenderCount) times. The render count depends on how many times the downloader calls the
 * progressImage block.
 */
- (void)hierarchyDisplayDidFinish;

/**
 * Only ASLayoutRangeModeVisibleOnly or ASLayoutRangeModeLowMemory are recommended.  Default is ASLayoutRangeModeVisibleOnly,
 * because this is the only way to ensure an application will not have blank / flashing views as the user navigates back after
 * a memory warning.  Apps that wish to use the more effective / aggressive ASLayoutRangeModeLowMemory may need to take steps
 * to mitigate this behavior, including: restoring a larger range mode to the next controller before the user navigates there,
 * enabling .neverShowPlaceholders on ASCellNodes so that the navigation operation is blocked on redisplay completing, etc.
 */
+ (void)setRangeModeForMemoryWarnings:(ASLayoutRangeMode)rangeMode;

@end

NS_ASSUME_NONNULL_END

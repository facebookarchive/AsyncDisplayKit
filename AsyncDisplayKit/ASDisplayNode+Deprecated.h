//
//  ASDisplayNode+Deprecated.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import "ASDisplayNode.h"

@interface ASDisplayNode (Deprecated)

/**
 * @abstract The name of this node, which will be displayed in `description`. The default value is nil.
 * 
 * @deprecated Deprecated in version 2.0: Use .debugName instead. This value will display in 
 * results of the -asciiArtString method (@see ASLayoutElementAsciiArtProtocol).
 */
@property (nullable, nonatomic, copy) NSString *name ASDISPLAYNODE_DEPRECATED_MSG("Use .debugName instead.");

/**
 * @abstract Provides a default intrinsic content size for calculateSizeThatFits:. This is useful when laying out
 * a node that either has no intrinsic content size or should be laid out at a different size than its intrinsic content
 * size. For example, this property could be set on an ASImageNode to display at a size different from the underlying
 * image size.
 *
 * @return Try to create a CGSize for preferredFrameSize of this node from the width and height property of this node. It will return CGSizeZero if widht and height dimensions are not of type ASDimensionUnitPoints.
 *
 * @deprecated Deprecated in version 2.0: Just calls through to set the height and width property of the node. Convert to use sizing properties instead: height, minHeight, maxHeight, width, minWidth, maxWidth.
 */
@property (nonatomic, assign, readwrite) CGSize preferredFrameSize ASDISPLAYNODE_DEPRECATED_MSG("Use .style.preferredSize instead OR set individual values with .style.height and .style.width.");

/**
 * @abstract Called whenever the visiblity of the node changed.
 *
 * @discussion Subclasses may use this to monitor when they become visible.
 *
 * @deprecated @see didEnterVisibleState @see didExitVisibleState
 */
- (void)visibilityDidChange:(BOOL)isVisible ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED_MSG("Use -didEnterVisibleState / -didExitVisibleState instead.");

/**
 * @abstract Called whenever the visiblity of the node changed.
 *
 * @discussion Subclasses may use this to monitor when they become visible.
 *
 * @deprecated @see didEnterVisibleState @see didExitVisibleState
 */
- (void)visibleStateDidChange:(BOOL)isVisible ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED_MSG("Use -didEnterVisibleState / -didExitVisibleState instead.");

/**
 * @abstract Called whenever the the node has entered or exited the display state.
 *
 * @discussion Subclasses may use this to monitor when a node should be rendering its content.
 *
 * @note This method can be called from any thread and should therefore be thread safe.
 *
 * @deprecated @see didEnterDisplayState @see didExitDisplayState
 */
- (void)displayStateDidChange:(BOOL)inDisplayState ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED_MSG("Use -didEnterDisplayState / -didExitDisplayState instead.");

/**
 * @abstract Called whenever the the node has entered or left the load state.
 *
 * @discussion Subclasses may use this to monitor data for a node should be loaded, either from a local or remote source.
 *
 * @note This method can be called from any thread and should therefore be thread safe.
 *
 * @deprecated @see didEnterPreloadState @see didExitPreloadState
 */
- (void)loadStateDidChange:(BOOL)inLoadState ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED_MSG("Use -didEnterPreloadState / -didExitPreloadState instead.");

/**
 * @abstract Cancels all performing layout transitions. Can be called on any thread.
 *
 * @deprecated Deprecated in version 2.0: Use cancelLayoutTransition
 */
- (void)cancelLayoutTransitionsInProgress ASDISPLAYNODE_DEPRECATED_MSG("Use -cancelLayoutTransition instead.");

/**
 * @abstract A boolean that shows whether the node automatically inserts and removes nodes based on the presence or
 * absence of the node and its subnodes is completely determined in its layoutSpecThatFits: method.
 *
 * @discussion If flag is YES the node no longer require addSubnode: or removeFromSupernode method calls. The presence
 * or absence of subnodes is completely determined in its layoutSpecThatFits: method.
 *
 * @deprecated Deprecated in version 2.0: Use automaticallyManagesSubnodes
 */
@property (nonatomic, assign) BOOL usesImplicitHierarchyManagement ASDISPLAYNODE_DEPRECATED_MSG("Set .automaticallyManagesSubnodes instead.");

@end

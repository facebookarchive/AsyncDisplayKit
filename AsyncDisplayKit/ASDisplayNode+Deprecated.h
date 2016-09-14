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
 * @abstract Called whenever the visiblity of the node changed.
 *
 * @discussion Subclasses may use this to monitor when they become visible.
 *
 * @deprecated @see didEnterVisibleState @see didExitVisibleState
 */
- (void)visibilityDidChange:(BOOL)isVisible ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Called whenever the visiblity of the node changed.
 *
 * @discussion Subclasses may use this to monitor when they become visible.
 *
 * @deprecated @see didEnterVisibleState @see didExitVisibleStat
 */
- (void)visibleStateDidChange:(BOOL)isVisible ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Called whenever the the node has entered or exited the display state.
 *
 * @discussion Subclasses may use this to monitor when a node should be rendering its content.
 *
 * @note This method can be called from any thread and should therefore be thread safe.
 *
 * @deprecated @see didEnterDisplayState @see didExitDisplayState
 */
- (void)displayStateDidChange:(BOOL)inDisplayState ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Called whenever the the node has entered or left the load state.
 *
 * @discussion Subclasses may use this to monitor data for a node should be loaded, either from a local or remote source.
 *
 * @note This method can be called from any thread and should therefore be thread safe.
 *
 * @deprecated @see didEnterPreloadState @see didExitPreloadState
 */
- (void)loadStateDidChange:(BOOL)inLoadState ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Cancels all performing layout transitions. Can be called on any thread.
 *
 * @deprecated Deprecated in version 2.0: Use cancelLayoutTransition
 */
- (void)cancelLayoutTransitionsInProgress ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract A boolean that shows whether the node automatically inserts and removes nodes based on the presence or
 * absence of the node and its subnodes is completely determined in its layoutSpecThatFits: method.
 *
 * @discussion If flag is YES the node no longer require addSubnode: or removeFromSupernode method calls. The presence
 * or absence of subnodes is completely determined in its layoutSpecThatFits: method.
 *
 * @deprecated Deprecated in version 2.0: Use automaticallyManagesSubnodes
 */
@property (nonatomic, assign) BOOL usesImplicitHierarchyManagement ASDISPLAYNODE_DEPRECATED;

- (void)reclaimMemory ASDISPLAYNODE_DEPRECATED;
- (void)recursivelyReclaimMemory ASDISPLAYNODE_DEPRECATED;
@property (nonatomic, assign) BOOL placeholderFadesOut ASDISPLAYNODE_DEPRECATED;

@end

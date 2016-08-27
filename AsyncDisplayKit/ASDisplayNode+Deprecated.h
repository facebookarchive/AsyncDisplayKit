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
 */
- (void)visibilityDidChange:(BOOL)isVisible ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Called whenever the visiblity of the node changed.
 *
 * @discussion Subclasses may use this to monitor when they become visible.
 */
- (void)visibleStateDidChange:(BOOL)isVisible ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Called whenever the the node has entered or exited the display state.
 *
 * @discussion Subclasses may use this to monitor when a node should be rendering its content.
 *
 * @note This method can be called from any thread and should therefore be thread safe.
 */
- (void)displayStateDidChange:(BOOL)inDisplayState ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

/**
 * @abstract Called whenever the the node has entered or left the load state.
 *
 * @discussion Subclasses may use this to monitor data for a node should be loaded, either from a local or remote source.
 *
 * @note This method can be called from any thread and should therefore be thread safe.
 * @deprecated @see didEnterPreloadState @see didExitPreloadState
 */
- (void)loadStateDidChange:(BOOL)inLoadState ASDISPLAYNODE_REQUIRES_SUPER ASDISPLAYNODE_DEPRECATED;

@end

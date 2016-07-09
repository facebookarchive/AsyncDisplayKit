//
//  ASDisplayNode+FrameworkPrivate.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

//
// The following methods are ONLY for use by _ASDisplayLayer, _ASDisplayView, and ASDisplayNode.
// These methods must never be called or overridden by other classes.
//

#import "_AS-objc-internal.h"
#import "ASDisplayNode.h"
#import "ASSentinel.h"
#import "ASThread.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Hierarchy state is propagated from nodes to all of their children when certain behaviors are required from the subtree.
 Examples include rasterization and external driving of the .interfaceState property.
 By passing this information explicitly, performance is optimized by avoiding iteration up the supernode chain.
 Lastly, this avoidance of supernode traversal protects against the possibility of deadlocks when a supernode is
 simultaneously attempting to materialize views / layers for its subtree (as many related methods require property locking)
 
 Note: as the hierarchy deepens, more state properties may be enabled.  However, state properties may never be disabled /
 cancelled below the point they are enabled.  They continue to the leaves of the hierarchy.
 */

typedef NS_OPTIONS(NSUInteger, ASHierarchyState)
{
  /** The node may or may not have a supernode, but no supernode has a special hierarchy-influencing option enabled. */
  ASHierarchyStateNormal                  = 0,
  /** The node has a supernode with .shouldRasterizeDescendants = YES.
      Note: the root node of the rasterized subtree (the one with the property set on it) will NOT have this state set. */
  ASHierarchyStateRasterized              = 1 << 0,
  /** The node or one of its supernodes is managed by a class like ASRangeController.  Most commonly, these nodes are
      ASCellNode objects or a subnode of one, and are used in ASTableView or ASCollectionView.
      These nodes also receive regular updates to the .interfaceState property with more detailed status information. */
  ASHierarchyStateRangeManaged            = 1 << 1,
  /** Down-propagated version of _flags.visibilityNotificationsDisabled.  This flag is very rarely set, but by having it
      locally available to nodes, they do not have to walk up supernodes at the critical points it is checked. */
  ASHierarchyStateTransitioningSupernodes = 1 << 2,
  /** One of the supernodes of this node is performing a transition.
      Any layout calculated during this state should not be applied immediately, but pending until later. */
  ASHierarchyStateLayoutPending           = 1 << 3
};

inline BOOL ASHierarchyStateIncludesLayoutPending(ASHierarchyState hierarchyState)
{
  return ((hierarchyState & ASHierarchyStateLayoutPending) == ASHierarchyStateLayoutPending);
}

inline BOOL ASHierarchyStateIncludesRangeManaged(ASHierarchyState hierarchyState)
{
    return ((hierarchyState & ASHierarchyStateRangeManaged) == ASHierarchyStateRangeManaged);
}

@interface ASDisplayNode ()
{
@protected
  ASInterfaceState _interfaceState;
  ASHierarchyState _hierarchyState;
}

// The view class to use when creating a new display node instance. Defaults to _ASDisplayView.
+ (Class)viewClass;

// These methods are recursive, and either union or remove the provided interfaceState to all sub-elements.
- (void)enterInterfaceState:(ASInterfaceState)interfaceState;
- (void)exitInterfaceState:(ASInterfaceState)interfaceState;
- (void)recursivelySetInterfaceState:(ASInterfaceState)interfaceState;

// These methods are recursive, and either union or remove the provided hierarchyState to all sub-elements.
- (void)enterHierarchyState:(ASHierarchyState)hierarchyState;
- (void)exitHierarchyState:(ASHierarchyState)hierarchyState;

// Changed before calling willEnterHierarchy / didExitHierarchy.
@property (nonatomic, readwrite, assign, getter = isInHierarchy) BOOL inHierarchy;
// Call willEnterHierarchy if necessary and set inHierarchy = YES if visibility notifications are enabled on all of its parents
- (void)__enterHierarchy;
// Call didExitHierarchy if necessary and set inHierarchy = NO if visibility notifications are enabled on all of its parents
- (void)__exitHierarchy;

/**
 * @abstract Returns the Hierarchy State of the node.
 *
 * @return The current ASHierarchyState of the node, indicating whether it is rasterized or managed by a range controller.
 *
 * @see ASInterfaceState
 */
@property (nonatomic, readwrite) ASHierarchyState hierarchyState;

/**
 * @abstract Return if the node is range managed or not
 *
 * @discussion Currently only set interface state on nodes in table and collection views. For other nodes, if they are
 * in the hierarchy we enable all ASInterfaceState types with `ASInterfaceStateInHierarchy`, otherwise `None`.
 */
- (BOOL)supportsRangeManagedInterfaceState;

// The two methods below will eventually be exposed, but their names are subject to change.
/**
 * @abstract Ensure that all rendering is complete for this node and its descendants.
 *
 * @discussion Calling this method on the main thread after a node is added to the view hierarchy will ensure that
 * placeholder states are never visible to the user.  It is used by ASTableView, ASCollectionView, and ASViewController
 * to implement their respective ".neverShowPlaceholders" option.
 *
 * If all nodes have layer.contents set and/or their layer does not have -needsDisplay set, the method will return immediately.
 *
 * This method is capable of handling a mixed set of nodes, with some not having started display, some in progress on an
 * asynchronous display operation, and some already finished.
 *
 * In order to guarantee against deadlocks, this method should only be called on the main thread.
 * It may block on the private queue, [_ASDisplayLayer displayQueue]
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

/**
 * @abstract Allows a node to bypass all ensureDisplay passes.  Defaults to NO.
 *
 * @discussion Nodes that are expensive to draw and expected to have placeholder even with
 * .neverShowPlaceholders enabled should set this to YES.
 *
 * ASImageNode uses the default of NO, as it is often used for UI images that are expected to synchronize with ensureDisplay.
 *
 * ASNetworkImageNode and ASMultiplexImageNode set this to YES, because they load data from a database or server,
 * and are expected to support a placeholder state given that display is often blocked on slow data fetching.
 */
@property (nonatomic, assign) BOOL shouldBypassEnsureDisplay;

/**
 * @abstract Checks whether a node should be scheduled for display, considering its current and new interface states.
 */
- (BOOL)shouldScheduleDisplayWithNewInterfaceState:(ASInterfaceState)newInterfaceState;

@end

@interface UIView (ASDisplayNodeInternal)
@property (nullable, nonatomic, assign, readwrite) ASDisplayNode *asyncdisplaykit_node;
@end

@interface CALayer (ASDisplayNodeInternal)
@property (nullable, nonatomic, assign, readwrite) ASDisplayNode *asyncdisplaykit_node;
@end

NS_ASSUME_NONNULL_END

/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 Given a layer, returns the associated display node, if any.
 */
extern ASDisplayNode * _Nullable ASLayerToDisplayNode(CALayer * _Nullable layer);

/**
 Given a view, returns the associated display node, if any.
 */
extern ASDisplayNode * _Nullable ASViewToDisplayNode(UIView * _Nullable view);

/**
 Given a node, returns the root of the node heirarchy (where supernode == nil)
 */
extern ASDisplayNode *ASDisplayNodeUltimateParentOfNode(ASDisplayNode *node);

/**
 This function will walk the layer heirarchy, spanning discontinuous sections of the node heirarchy (e.g. the layers
 of UIKit intermediate views in UIViewControllers, UITableView, UICollectionView).
 In the event that a node's backing layer is not created yet, the function will only walk the direct subnodes instead
 of forcing the layer heirarchy to be created.
 */
extern void ASDisplayNodePerformBlockOnEveryNode(CALayer * _Nullable layer, ASDisplayNode * _Nullable node, void(^block)(ASDisplayNode *node));

/**
 Identical to ASDisplayNodePerformBlockOnEveryNode, except it does not run the block on the
 node provided directly to the function call - only on all descendants.
 */
extern void ASDisplayNodePerformBlockOnEverySubnode(ASDisplayNode *node, void(^block)(ASDisplayNode *node));

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node that passes block.
 */
extern id _Nullable ASDisplayNodeFind(ASDisplayNode * _Nullable node, BOOL (^block)(ASDisplayNode *node));

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node of kind class.
 */
extern id _Nullable ASDisplayNodeFindClass(ASDisplayNode *start, Class c);

/**
 * Given two nodes, finds their most immediate common parent.  Used for geometry conversion methods.
 * NOTE: It is an error to try to convert between nodes which do not share a common ancestor. This behavior is
 * disallowed in UIKit documentation and the behavior is left undefined. The output does not have a rigorously defined
 * failure mode (i.e. returning CGPointZero or returning the point exactly as passed in). Rather than track the internal
 * undefined and undocumented behavior of UIKit in ASDisplayNode, this operation is defined to be incorrect in all
 * circumstances and must be fixed wherever encountered.
 */
extern ASDisplayNode * _Nullable ASDisplayNodeFindClosestCommonAncestor(ASDisplayNode *node1, ASDisplayNode *node2);

/**
 Given a display node, collects all descendents. This is a specialization of ASCollectContainer() that walks the Core Animation layer tree as opposed to the display node tree, thus supporting non-continues display node hierarchies.
 */
extern NSArray<ASDisplayNode *> *ASCollectDisplayNodes(ASDisplayNode *node);

/**
 Given a display node, traverses down the node hierarchy, returning all the display nodes that pass the block.
 */
extern NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodes(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node));

/**
 Given a display node, traverses down the node hierarchy, returning all the display nodes of kind class.
 */
extern NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodesOfClass(ASDisplayNode *start, Class c);

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node that pass the block.
 */
extern __kindof ASDisplayNode * ASDisplayNodeFindFirstSubnode(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node));

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node of kind class.
 */
extern __kindof ASDisplayNode * ASDisplayNodeFindFirstSubnodeOfClass(ASDisplayNode *start, Class c);

extern UIColor *ASDisplayNodeDefaultPlaceholderColor();
extern UIColor *ASDisplayNodeDefaultTintColor();

/**
 Disable willAppear / didAppear / didDisappear notifications for a sub-hierarchy, then re-enable when done. Nested calls are supported.
 */
extern void ASDisplayNodeDisableHierarchyNotifications(ASDisplayNode *node);
extern void ASDisplayNodeEnableHierarchyNotifications(ASDisplayNode *node);

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END

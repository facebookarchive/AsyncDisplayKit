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
 Given a display node, traverses up the layer tree hierarchy, returning the first display node that passes block.
 */
extern id ASDisplayNodeFind(ASDisplayNode * _Nullable node, BOOL (^block)(ASDisplayNode *node));

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node of kind class.
 */
extern id ASDisplayNodeFindClass(ASDisplayNode *start, Class c);

/**
 Given a display node, collects all descendents. This is a specialization of ASCollectContainer() that walks the Core Animation layer tree as opposed to the display node tree, thus supporting non-continuous display node hierarchies.
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

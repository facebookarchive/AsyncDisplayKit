//
//  ASDisplayNodeExtras.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

/**
 * Sets the debugName field for these nodes to the given symbol names, within the domain of "self.class"
 * For instance, in `MYButtonNode` if you call `ASSetDebugNames(self.titleNode, _countNode)` the debug names
 * for the nodes will be set to `MYButtonNode.titleNode` and `MYButtonNode.countNode`.
 */
#if DEBUG
  #define ASSetDebugNames(...) _ASSetDebugNames(self.class, @"" # __VA_ARGS__, __VA_ARGS__, nil)
#else
  #define ASSetDebugNames(...)
#endif

/// For deallocation of objects on the main thread across multiple run loops.
extern void ASPerformMainThreadDeallocation(_Nullable id object);

// Because inline methods can't be extern'd and need to be part of the translation unit of code
// that compiles with them to actually inline, we both declare and define these in the header.
ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesVisible(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateVisible) == ASInterfaceStateVisible);
}

ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesDisplay(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateDisplay) == ASInterfaceStateDisplay);
}

ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesPreload(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStatePreload) == ASInterfaceStatePreload);
}

ASDISPLAYNODE_INLINE BOOL ASInterfaceStateIncludesMeasureLayout(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateMeasureLayout) == ASInterfaceStateMeasureLayout);
}

__unused static NSString * _Nonnull NSStringFromASInterfaceState(ASInterfaceState interfaceState)
{
  NSMutableArray *states = [NSMutableArray array];
  if (interfaceState == ASInterfaceStateNone) {
    [states addObject:@"No state"];
  }
  if (ASInterfaceStateIncludesMeasureLayout(interfaceState)) {
    [states addObject:@"MeasureLayout"];
  }
  if (ASInterfaceStateIncludesPreload(interfaceState)) {
    [states addObject:@"Preload"];
  }
  if (ASInterfaceStateIncludesDisplay(interfaceState)) {
    [states addObject:@"Display"];
  }
  if (ASInterfaceStateIncludesVisible(interfaceState)) {
    [states addObject:@"Visible"];
  }
  return [NSString stringWithFormat:@"{ %@ }", [states componentsJoinedByString:@" | "]];
}

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 Returns the appropriate interface state for a given ASDisplayNode and window
 */
extern ASInterfaceState ASInterfaceStateForDisplayNode(ASDisplayNode *displayNode, UIWindow *window) AS_WARN_UNUSED_RESULT;

/**
 Given a layer, returns the associated display node, if any.
 */
extern ASDisplayNode * _Nullable ASLayerToDisplayNode(CALayer * _Nullable layer) AS_WARN_UNUSED_RESULT;

/**
 Given a view, returns the associated display node, if any.
 */
extern ASDisplayNode * _Nullable ASViewToDisplayNode(UIView * _Nullable view) AS_WARN_UNUSED_RESULT;

/**
 Given a node, returns the root of the node heirarchy (where supernode == nil)
 */
extern ASDisplayNode *ASDisplayNodeUltimateParentOfNode(ASDisplayNode *node) AS_WARN_UNUSED_RESULT;

/**
 If traverseSublayers == YES, this function will walk the layer hierarchy, spanning discontinuous sections of the node hierarchy\
 (e.g. the layers of UIKit intermediate views in UIViewControllers, UITableView, UICollectionView).
 In the event that a node's backing layer is not created yet, the function will only walk the direct subnodes instead
 of forcing the layer hierarchy to be created.
 */
extern void ASDisplayNodePerformBlockOnEveryNode(CALayer * _Nullable layer, ASDisplayNode * _Nullable node, BOOL traverseSublayers, void(^block)(ASDisplayNode *node));

/**
 This function will walk the node hierarchy in a breadth first fashion. It does run the block on the node provided
 directly to the function call.  It does NOT traverse sublayers.
 */
extern void ASDisplayNodePerformBlockOnEveryNodeBFS(ASDisplayNode *node, void(^block)(ASDisplayNode *node));

/**
 Identical to ASDisplayNodePerformBlockOnEveryNode, except it does not run the block on the
 node provided directly to the function call - only on all descendants.
 */
extern void ASDisplayNodePerformBlockOnEverySubnode(ASDisplayNode *node, BOOL traverseSublayers, void(^block)(ASDisplayNode *node));

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node that passes block.
 */
extern ASDisplayNode * _Nullable ASDisplayNodeFindFirstSupernode(ASDisplayNode * _Nullable node, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses up the layer tree hierarchy, returning the first display node of kind class.
 */
extern __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstSupernodeOfClass(ASDisplayNode *start, Class c) AS_WARN_UNUSED_RESULT;

/**
 * Given a layer, find the window it lives in, if any.
 */
extern UIWindow * _Nullable ASFindWindowOfLayer(CALayer *layer) AS_WARN_UNUSED_RESULT;

/**
 * Given a layer, find the closest view it lives in, if any.
 */
extern UIView * _Nullable ASFindClosestViewOfLayer(CALayer *layer) AS_WARN_UNUSED_RESULT;

/**
 * Given two nodes, finds their most immediate common parent.  Used for geometry conversion methods.
 * NOTE: It is an error to try to convert between nodes which do not share a common ancestor. This behavior is
 * disallowed in UIKit documentation and the behavior is left undefined. The output does not have a rigorously defined
 * failure mode (i.e. returning CGPointZero or returning the point exactly as passed in). Rather than track the internal
 * undefined and undocumented behavior of UIKit in ASDisplayNode, this operation is defined to be incorrect in all
 * circumstances and must be fixed wherever encountered.
 */
extern ASDisplayNode * _Nullable ASDisplayNodeFindClosestCommonAncestor(ASDisplayNode *node1, ASDisplayNode *node2) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, collects all descendants. This is a specialization of ASCollectContainer() that walks the Core Animation layer tree as opposed to the display node tree, thus supporting non-continues display node hierarchies.
 */
extern NSArray<ASDisplayNode *> *ASCollectDisplayNodes(ASDisplayNode *node) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning all the display nodes that pass the block.
 */
extern NSArray<ASDisplayNode *> *ASDisplayNodeFindAllSubnodes(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning all the display nodes of kind class.
 */
extern NSArray<__kindof ASDisplayNode *> *ASDisplayNodeFindAllSubnodesOfClass(ASDisplayNode *start, Class c) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node, including the start node that pass the block.
 */
extern __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstNode(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node, excluding the start node, that pass the block
 */
extern __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstSubnode(ASDisplayNode *start, BOOL (^block)(ASDisplayNode *node)) AS_WARN_UNUSED_RESULT;

/**
 Given a display node, traverses down the node hierarchy, returning the depth-first display node of kind class.
 */
extern __kindof ASDisplayNode * _Nullable ASDisplayNodeFindFirstSubnodeOfClass(ASDisplayNode *start, Class c) AS_WARN_UNUSED_RESULT;

extern UIColor *ASDisplayNodeDefaultPlaceholderColor() AS_WARN_UNUSED_RESULT;
extern UIColor *ASDisplayNodeDefaultTintColor() AS_WARN_UNUSED_RESULT;

/**
 Disable willAppear / didAppear / didDisappear notifications for a sub-hierarchy, then re-enable when done. Nested calls are supported.
 */
extern void ASDisplayNodeDisableHierarchyNotifications(ASDisplayNode *node);
extern void ASDisplayNodeEnableHierarchyNotifications(ASDisplayNode *node);

// Not to be called directly.
extern void _ASSetDebugNames(Class _Nonnull owningClass, NSString * _Nonnull names, ASDisplayNode * _Nullable object, ...);

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END

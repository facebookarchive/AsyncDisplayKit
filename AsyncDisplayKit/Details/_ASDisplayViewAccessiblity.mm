//
//  _ASDisplayViewAccessiblity.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#ifndef ASDK_ACCESSIBILITY_DISABLE

#import "_ASDisplayView.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+FrameworkPrivate.h"

#pragma mark - UIAccessibilityElement

typedef NSComparisonResult (^SortAccessibilityElementsComparator)(UIAccessibilityElement *, UIAccessibilityElement *);

/// Sort accessiblity elements first by y and than by x origin.
static void SortAccessibilityElements(NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  
  static SortAccessibilityElementsComparator comparator = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      comparator = ^NSComparisonResult(UIAccessibilityElement *a, UIAccessibilityElement *b) {
        CGPoint originA = a.accessibilityFrame.origin;
        CGPoint originB = b.accessibilityFrame.origin;
        if (originA.y == originB.y) {
          if (originA.x == originB.x) {
            return NSOrderedSame;
          }
          return (originA.x < originB.x) ? NSOrderedAscending : NSOrderedDescending;
        }
        return (originA.y < originB.y) ? NSOrderedAscending : NSOrderedDescending;
      };
  });
  [elements sortUsingComparator:comparator];
}

@implementation UIAccessibilityElement (_ASDisplayView)

+ (UIAccessibilityElement *)accessibilityElementWithContainer:(id)container node:(ASDisplayNode *)node
{
  UIAccessibilityElement *accessibilityElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:container];
  accessibilityElement.accessibilityIdentifier = node.accessibilityIdentifier;
  accessibilityElement.accessibilityLabel = node.accessibilityLabel;
  accessibilityElement.accessibilityHint = node.accessibilityHint;
  accessibilityElement.accessibilityValue = node.accessibilityValue;
  accessibilityElement.accessibilityTraits = node.accessibilityTraits;
  return accessibilityElement;
}

@end


#pragma mark - _ASDisplayView / UIAccessibilityContainer

/// Collect all subnodes for the given node by walking down the subnode tree and calculates the screen coordinates based on the containerNode and container
static void CollectUIAccessibilityElementsForNode(ASDisplayNode *node, ASDisplayNode *containerNode, id container, NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  
  ASDisplayNodePerformBlockOnEveryNodeBFS(node, ^(ASDisplayNode * _Nonnull currentNode) {
    // For every subnode that is layer backed or it's supernode has shouldRasterizeDescendants enabled
    // we have to create a UIAccessibilityElement as no view for this node exists
    if (currentNode != containerNode && currentNode.isAccessibilityElement) {
      UIAccessibilityElement *accessibilityElement = [UIAccessibilityElement accessibilityElementWithContainer:container node:currentNode];
      // As the node hierarchy is flattened it's necessary to convert the frame for each subnode in the tree to the
      // coordinate system of the supernode
      CGRect frame = [containerNode convertRect:currentNode.bounds fromNode:currentNode];
      accessibilityElement.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(frame, container);
      [elements addObject:accessibilityElement];
    }
  });
}

/// Collect all accessibliity elements for a given view and view node
static void CollectAccessibilityElementsForView(_ASDisplayView *view, NSMutableArray *elements)
{
  ASDisplayNodeCAssertNotNil(elements, @"Should pass in a NSMutableArray");
  
  ASDisplayNode *node = view.asyncdisplaykit_node;
  
  // Handle rasterize case
  if (node.shouldRasterizeDescendants) {
    CollectUIAccessibilityElementsForNode(node, node, view, elements);
    return;
  }
  
  for (ASDisplayNode *subnode in node.subnodes) {
    if (subnode.isAccessibilityElement) {
      
      // An accessiblityElement can either be a UIView or a UIAccessibilityElement
      id accessiblityElement = nil;
      if (subnode.isLayerBacked) {
        // No view for layer backed nodes exist. It's necessary to create a UIAccessibilityElement that represents this node
        accessiblityElement = [UIAccessibilityElement accessibilityElementWithContainer:view node:subnode];
        
        CGRect frame = [node convertRect:subnode.bounds fromNode:subnode];
        [accessiblityElement setAccessibilityFrame:UIAccessibilityConvertFrameToScreenCoordinates(frame, view)];
        [elements addObject:accessiblityElement];
      } else {
        // Accessiblity element is not layer backed just translate the view's frame to the container and add the view
        accessiblityElement = subnode.view;
        [accessiblityElement setAccessibilityFrame:UIAccessibilityConvertFrameToScreenCoordinates(subnode.frame, view)];
        [elements addObject:accessiblityElement];
      }
      
    } else if (subnode.isLayerBacked) {
      // Go down the hierarchy of the layer backed subnode and collect all of the UIAccessibilityElement
      CollectUIAccessibilityElementsForNode(subnode, node, view, elements);
    } else if ([subnode accessibilityElementCount] > 0) {
      // UIView is itself a UIAccessibilityContainer just add it
      [elements addObject:subnode.view];
    }
  }
}

@interface _ASDisplayView () {
  NSArray *_accessibleElements;
  CGRect _lastAccessibleElementsFrame;
}

@end

@implementation _ASDisplayView (UIAccessibilityContainer)

#pragma mark - UIAccessibility

- (void)setAccessibleElements:(NSArray *)accessibleElements
{
  _accessibleElements = nil;
}

- (NSArray *)accessibleElements
{
  ASDisplayNode *viewNode = self.asyncdisplaykit_node;
  if (viewNode == nil) {
    return @[];
  }
  
  CGRect screenFrame = UIAccessibilityConvertFrameToScreenCoordinates(self.bounds, self);
  if (_accessibleElements != nil && CGRectEqualToRect(_lastAccessibleElementsFrame, screenFrame)) {
    return _accessibleElements;
  }
  
  _lastAccessibleElementsFrame = screenFrame;
  
  NSMutableArray *accessibleElements = [NSMutableArray array];
  CollectAccessibilityElementsForView(self, accessibleElements);
  SortAccessibilityElements(accessibleElements);
  _accessibleElements = accessibleElements;
  
  return _accessibleElements;
}

- (NSInteger)accessibilityElementCount
{
  return self.accessibleElements.count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  return self.accessibleElements[index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  return [self.accessibleElements indexOfObjectIdenticalTo:element];
}

@end

#endif

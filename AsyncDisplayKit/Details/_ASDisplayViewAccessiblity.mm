//
//  _ASDisplayViewAccessiblity.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "_ASDisplayView.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+FrameworkPrivate.h"

#pragma mark - UIAccessibilityElement

// Sort accessiblity elements by x and y origin. First sort the elements by y and than by x value.
static NSArray *SortAccessibilityElements(NSArray *accessibleElements) {
  return [accessibleElements sortedArrayUsingComparator:^NSComparisonResult(UIAccessibilityElement *a, UIAccessibilityElement *b) {
    CGPoint originA = a.accessibilityFrame.origin;
    CGPoint originB = b.accessibilityFrame.origin;
    if (originA.y == originB.y) {
      if (originA.x == originB.x) {
        return NSOrderedSame;
      } else if (originA.x < originB.x) {
        return NSOrderedAscending;
      } else {
        return NSOrderedDescending;
      }
    } else if (originA.y < originB.y) {
      return NSOrderedAscending;
    } else {
      return NSOrderedDescending;
    }
  }];
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

static NSArray *ASCollectUIAccessibilityElementsForNode(ASDisplayNode *viewNode, ASDisplayNode *subnode, id container)
{
  NSMutableArray *accessibleElements = [NSMutableArray array];
  ASDisplayNodePerformBlockOnEveryNodeBFS(subnode, ^(ASDisplayNode * _Nonnull currentNode) {
    // For every subnode that is layer backed or it's supernode has shouldRasterizeDescendants enabled
    // we have to create a UIAccessibilityElement as no view for this node exists
    if (currentNode != viewNode && currentNode.isAccessibilityElement) {
      UIAccessibilityElement *accessibilityElement = [UIAccessibilityElement accessibilityElementWithContainer:container node:currentNode];
      // As the node hierarchy is flattened it's necessary to convert the frame for each subnode in the tree to the
      // coordinate system of the supernode
      CGRect frame = [viewNode convertRect:currentNode.bounds fromNode:currentNode];
      accessibilityElement.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(frame, container);
      [accessibleElements addObject:accessibilityElement];
    }
  });
  
  return [accessibleElements copy];
}

static NSArray *CollectAccessibilityElementsForViewAndNode(_ASDisplayView *view, ASDisplayNode *viewNode)
{
  // Handle rasterize case
  if (viewNode.shouldRasterizeDescendants) {
    return ASCollectUIAccessibilityElementsForNode(viewNode, viewNode, view);
  }
  
  // Handle not rasterize case
  NSMutableArray *elements = [NSMutableArray array];
  
  for (ASDisplayNode *subnode in viewNode.subnodes) {
    if (subnode.isAccessibilityElement) {
      
      // An accessiblityElement can either be a UIView or a UIAccessibilityElement
      id accessiblityElement = nil;
      if (subnode.isLayerBacked) {
        // No view for layer backed nodes exist. It's necessary to create a UIAccessibilityElement that represents this node
        accessiblityElement = [UIAccessibilityElement accessibilityElementWithContainer:view node:subnode];
        
        CGRect frame = [viewNode convertRect:subnode.bounds fromNode:subnode];
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
      [elements addObjectsFromArray:ASCollectUIAccessibilityElementsForNode(viewNode, subnode, view)];
    } else if ([subnode accessibilityElementCount] > 0) {
      // Add UIAccessibilityContainer
      [elements addObject:subnode.view];
    }
  }
    
  return [elements copy];
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
  
  CGRect screenFrame = UIAccessibilityConvertFrameToScreenCoordinates(self.frame, self);
  if (_accessibleElements != nil && CGRectEqualToRect(_lastAccessibleElementsFrame, screenFrame)) {
    return _accessibleElements;
  }
  
  _accessibleElements = SortAccessibilityElements(CollectAccessibilityElementsForViewAndNode(self, viewNode));
  _lastAccessibleElementsFrame = screenFrame;
  
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
  return [self.accessibleElements indexOfObject:element];
}

@end

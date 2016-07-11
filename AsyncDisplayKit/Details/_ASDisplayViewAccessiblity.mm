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

static NSArray *ASCollectUIAccessibilityElementsForNode(ASDisplayNode *viewNode, ASDisplayNode *subnode, id container) {
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

@interface _ASDisplayView () {
  NSArray *_accessibleElements;
}
@end

@implementation _ASDisplayView (UIAccessibilityContainer)

#pragma mark - UIAccessibility

- (NSArray *)accessibleElements
{
  ASDisplayNode *viewNode = self.asyncdisplaykit_node;
  if (viewNode == nil) {
    return nil;
  }
  
  // Handle rasterize case
  if (viewNode.shouldRasterizeDescendants) {
    _accessibleElements = ASCollectUIAccessibilityElementsForNode(viewNode, viewNode, self);
    return _accessibleElements;
  }
  
  // Handle not rasterize case
  NSMutableArray *accessibleElements = [NSMutableArray array];
  
  for (ASDisplayNode *subnode in viewNode.subnodes) {
    if (subnode.isAccessibilityElement) {
      // An accessiblityElement can either be a UIView or a UIAccessibilityElement
      id accessiblityElement = nil;
      if (subnode.isLayerBacked) {
        // No view for layer backed nodes exist. It's necessary to create a UIAccessibilityElement that represents this node
        accessiblityElement = [UIAccessibilityElement accessibilityElementWithContainer:self node:subnode];
      } else {
        accessiblityElement = subnode.view;
      }
      [accessiblityElement setAccessibilityFrame:UIAccessibilityConvertFrameToScreenCoordinates(subnode.frame, self)];
      [accessibleElements addObject:accessiblityElement];
    } else if (subnode.isLayerBacked) {
      // Go down the hierarchy of the layer backed subnode and collect all of the UIAccessibilityElement
      [accessibleElements addObjectsFromArray:ASCollectUIAccessibilityElementsForNode(viewNode, subnode, self)];
    } else if ([subnode accessibilityElementCount] > 0) {
      // Add UIAccessibilityContainer
      [accessibleElements addObject:subnode.view];
    }
  }
  _accessibleElements = [accessibleElements copy];
  
  return _accessibleElements;
}

- (NSInteger)accessibilityElementCount
{
  return [self accessibleElements].count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  ASDisplayNodeAssertNotNil(_accessibleElements, @"At this point _accessibleElements should be created.");
  if (_accessibleElements == nil) {
    return nil;
  }
  
  return _accessibleElements[index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  if (_accessibleElements == nil) {
    return NSNotFound;
  }
  
  return [_accessibleElements indexOfObject:element];
}

@end

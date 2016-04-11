/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASDisplayViewAccessiblity.h"
#import "_ASDisplayView.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+FrameworkPrivate.h"

#import <objc/runtime.h>


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

@interface _ASDisplayView () {
  NSMutableArray *_accessibleElements;
}

@end

@implementation _ASDisplayView (UIAccessibilityContainer)

#pragma mark - UIAccessibility

- (NSArray *)accessibleElements
{
  ASDisplayNode *selfNode = self.asyncdisplaykit_node;
  if (selfNode == nil) {
    return nil;
  }
  
  _accessibleElements = [[NSMutableArray alloc] init];
  
  // Handle rasterize case
  if (selfNode.shouldRasterizeDescendants) {
    // If the node has shouldRasterizeDescendants enabled it's necessaty to go through the whole subnodes
    // tree of the node in BFS fashion and create for all subnodes UIAccessibilityElement objects ourselves
    // as the view hierarchy is flattened
    ASDisplayNodePerformBlockOnEveryNodeBFS(selfNode, ^(ASDisplayNode * _Nonnull node) {
      // For every subnode we have to create a UIAccessibilityElement as we cannot just add the view to the
      // accessibleElements as for a subnode of a node with shouldRasterizeDescendants enabled no view exists
      if (node != selfNode && node.isAccessibilityElement) {
        UIAccessibilityElement *accessibilityElement = [UIAccessibilityElement accessibilityElementWithContainer:self node:node];
        // As the node hierarchy is flattened it's necessary to convert the frame for each subnode in the tree to the
        // coordinate system of the node with shouldRasterizeDescendants enabled
        CGRect frame = [selfNode convertRect:node.bounds fromNode:node];
        accessibilityElement.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(frame, self);
        [_accessibleElements addObject:accessibilityElement];
      }
    });
    return _accessibleElements;
  }
  
  // Handle not rasterize case
  // Create UI accessiblity elements for each subnode that represent an elment within the accessibility container
  for (ASDisplayNode *subnode in selfNode.subnodes) {
    if (subnode.isAccessibilityElement) {
      id accessiblityElement = nil;
      if (subnode.isLayerBacked) {
        // The same comment for layer backed nodes is true as for subnodes within a shouldRasterizeDescendants node.
        // See details above
        accessiblityElement = [UIAccessibilityElement accessibilityElementWithContainer:self node:subnode];
      } else {
        accessiblityElement = subnode.view;
      }
      [accessiblityElement setAccessibilityFrame:UIAccessibilityConvertFrameToScreenCoordinates(subnode.frame, self)];
      [_accessibleElements addObject:accessiblityElement];
    } else if ([subnode accessibilityElementCount] > 0) { // Check if it's an UIAccessibilityContainer
      [_accessibleElements addObject:subnode.view];
    }
  }
  
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

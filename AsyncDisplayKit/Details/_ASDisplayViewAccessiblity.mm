/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASDisplayViewAccessiblity.h"
#import "_ASDisplayView.h"
#import "ASDisplayNode+FrameworkPrivate.h"

#import <objc/runtime.h>
#import <queue>


#pragma mark - UIAccessibilityElement

static const char *ASDisplayNodeAssociatedNodeKey = "ASAssociatedNode";

@implementation UIAccessibilityElement (_ASDisplayView)

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, node, OBJC_ASSOCIATION_ASSIGN); // Weak reference to avoid cycle, since the node retains the layer.
  
  // Update UIAccessibilityElement properties from node
  self.accessibilityIdentifier = node.accessibilityIdentifier;
  self.accessibilityLabel = node.accessibilityLabel;
  self.accessibilityHint = node.accessibilityHint;
  self.accessibilityValue = node.accessibilityValue;
  self.accessibilityTraits = node.accessibilityTraits;
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  return objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
}

@end


#pragma mark - _ASDisplayView

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
    // In this case we have to go through the whole subnodes tree in BFS fashion and create all
    // accessibility elements ourselves as the view hierarchy is flattened
    
    // Queue used to keep track of subnodes while traversing this layout in a BFS fashion.
    std::queue<ASDisplayNode *> queue;
    queue.push(selfNode);
    
    while (!queue.empty()) {
      ASDisplayNode *node = queue.front();
      queue.pop();
      
      // Check if we have to add the node to the accessiblity nodes as it's an accessiblity element
      if (node != selfNode && node.isAccessibilityElement) {
        UIAccessibilityElement *accessibilityElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
        accessibilityElement.asyncdisplaykit_node = node;
        [_accessibleElements addObject:accessibilityElement];
      }

      // Add all subnodes to process in next step
      for (int i = 0; i < node.subnodes.count; i++)
        queue.push(node.subnodes[i]);
    }
    return _accessibleElements;
  }
  
  // Handle not rasterize case
  // Create UI accessiblity elements for each subnode that represent an elment within the accessibility container
  for (ASDisplayNode *subnode in selfNode.subnodes) {
      // Check if this subnode is a UIAccessibilityContainer
    if (!subnode.isAccessibilityElement && [subnode accessibilityElementCount] > 0) {
      // We are good and the view is an UIAccessibilityContainer so add it
      [_accessibleElements addObject:subnode.view];
    } else if (subnode.isAccessibilityElement) {
      // Create a accessiblity element from the subnode
      UIAccessibilityElement *accessibilityElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
      accessibilityElement.asyncdisplaykit_node = subnode;
      [_accessibleElements addObject:accessibilityElement];
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
  if (_accessibleElements == nil) {
    return nil;
  }
  
  UIAccessibilityElement *accessibilityElement = [_accessibleElements objectAtIndex:index];
  ASDisplayNode *accessibilityElementNode = accessibilityElement.asyncdisplaykit_node;
  if (accessibilityElementNode == nil) {
    return nil;
  }
  
  // We have to update the accessiblity frame in accessibilityElementAtIndex: as the accessibility frame is in screen
  // coordinates and between creating the accessibilityElement and returning it in accessibilityElementAtIndex:
  // the frame can change
  
  // Handle if node is rasterized
  ASDisplayNode *selfNode = self.asyncdisplaykit_node;
  if (selfNode.shouldRasterizeDescendants) {
    // We need to convert the accessibilityElementNode frame into the coordinate system of the selfNode
    CGRect frame = [selfNode convertRect:accessibilityElementNode.bounds fromNode:accessibilityElementNode];
    accessibilityElement.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(frame, self);
    return accessibilityElement;
  }

  // Handle non rasterized case
  accessibilityElement.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(accessibilityElementNode.frame, self);
  return accessibilityElement;
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  if (_accessibleElements == nil) {
    return NSNotFound;
  }
  
  return [_accessibleElements indexOfObject:element];
}

@end

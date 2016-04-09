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
  accessibilityElement.asyncdisplaykit_node = node;
  return accessibilityElement;
}

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  objc_setAssociatedObject(self, @selector(asyncdisplaykit_node), node, OBJC_ASSOCIATION_ASSIGN);

  self.accessibilityIdentifier = node.accessibilityIdentifier;
  self.accessibilityLabel = node.accessibilityLabel;
  self.accessibilityHint = node.accessibilityHint;
  self.accessibilityValue = node.accessibilityValue;
  self.accessibilityTraits = node.accessibilityTraits;
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  return objc_getAssociatedObject(self, @selector(asyncdisplaykit_node));
}

@end


#pragma mark - _ASDisplayView / UIAccessibilityContainer

static BOOL ASNodeIsAccessiblityContainer(ASDisplayNode *node) {
  return (!node.isAccessibilityElement && [node accessibilityElementCount] > 0);
}

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
    ASDisplayNodePerformBlockOnEveryNodeBFS(selfNode, ^(ASDisplayNode * _Nonnull node) {
      // For every subnode we have to create a UIAccessibilityElement as we cannot just add the view to the
      // accessibleElements as for a subnode of a node with shouldRasterizeDescendants enabled no view exists
      if (node != selfNode && node.isAccessibilityElement) {
        [_accessibleElements addObject:[UIAccessibilityElement accessibilityElementWithContainer:self node:node]];
      }
    });
    return _accessibleElements;
  }
  
  // Handle not rasterize case
  // Create UI accessiblity elements for each subnode that represent an elment within the accessibility container
  for (ASDisplayNode *subnode in selfNode.subnodes) {
    if (subnode.isAccessibilityElement) {
      if (subnode.isLayerBacked) {
        // The same comment for layer backed subnodes is true as for subnodes within a shouldRasterizeDescendants node.
        // See details above
        [_accessibleElements addObject:[UIAccessibilityElement accessibilityElementWithContainer:self node:subnode]];
      } else {
        [_accessibleElements addObject:subnode.view];
      }
    } else if (ASNodeIsAccessiblityContainer(subnode)) {
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

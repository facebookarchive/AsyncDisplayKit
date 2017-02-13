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

#import <AsyncDisplayKit/_ASDisplayView.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>

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

@interface ASAccessibilityElement : UIAccessibilityElement

@property (nonatomic, strong) ASDisplayNode *node;
@property (nonatomic, strong) ASDisplayNode *containerNode;

+ (ASAccessibilityElement *)accessibilityElementWithContainer:(UIView *)container node:(ASDisplayNode *)node containerNode:(ASDisplayNode *)containerNode;

@end

@implementation ASAccessibilityElement

+ (ASAccessibilityElement *)accessibilityElementWithContainer:(UIView *)container node:(ASDisplayNode *)node containerNode:(ASDisplayNode *)containerNode
{
  ASAccessibilityElement *accessibilityElement = [[ASAccessibilityElement alloc] initWithAccessibilityContainer:container];
  accessibilityElement.node = node;
  accessibilityElement.containerNode = containerNode;
  accessibilityElement.accessibilityIdentifier = node.accessibilityIdentifier;
  accessibilityElement.accessibilityLabel = node.accessibilityLabel;
  accessibilityElement.accessibilityHint = node.accessibilityHint;
  accessibilityElement.accessibilityValue = node.accessibilityValue;
  accessibilityElement.accessibilityTraits = node.accessibilityTraits;
  return accessibilityElement;
}

- (CGRect)accessibilityFrame
{
  CGRect accessibilityFrame = [self.containerNode convertRect:self.node.bounds fromNode:self.node];
  accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(accessibilityFrame, self.accessibilityContainer);
  return accessibilityFrame;
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
      UIAccessibilityElement *accessibilityElement = [ASAccessibilityElement accessibilityElementWithContainer:container node:currentNode containerNode:containerNode];
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
      if (subnode.isLayerBacked) {
        // No view for layer backed nodes exist. It's necessary to create a UIAccessibilityElement that represents this node
        UIAccessibilityElement *accessiblityElement = [ASAccessibilityElement accessibilityElementWithContainer:view node:subnode containerNode:node];
        [elements addObject:accessiblityElement];
      } else {
        // Accessiblity element is not layer backed just add the view as accessibility element
        [elements addObject:subnode.view];
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
  
  if (_accessibleElements != nil) {
    return _accessibleElements;
  }
  
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

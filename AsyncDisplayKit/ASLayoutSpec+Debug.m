//
//  ASLayoutSpec+Debug.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/20/16.
//
//

#import "ASLayoutSpec+Debug.h"
#import "ASDisplayNode+Beta.h"
#import "AsyncDisplayKit.h"
#import "ASLayoutableInspectorNode.h"

@implementation ASLayoutSpec (Debugging2)



@end


@implementation ASLayoutSpecVisualizerNode

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec
{
  self = [super init];
  if (self) {
    self.layoutSpec = layoutSpec;
    self.usesImplicitHierarchyManagement = YES;
    self.layer.borderColor = [[UIColor redColor] CGColor];
    self.layer.borderWidth = 2;
    [self addTarget:self action:@selector(layoutMagicNodeTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
  insetSpec.shouldVisualize = YES;
  self.layoutSpec.shouldVisualize = YES;
  UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
  insetSpec.insets = insets;
  insetSpec.child = self.layoutSpec;
  return insetSpec;
}

- (void)layoutMagicNodeTapped:(UIGestureRecognizer *)sender
{
  NSLog(@"SELECTED: %@", self);
  [[ASLayoutableInspectorNode sharedInstance] setLayoutableToEdit:self];
}

@end


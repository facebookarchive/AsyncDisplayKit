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

static BOOL __shouldVisualizeLayoutSpecs = NO;
+ (BOOL)shouldVisualizeLayoutSpecs2
{
  return __shouldVisualizeLayoutSpecs;
}

+ (void)setShouldVisualizeLayoutSpecs2:(BOOL)shouldVisualizeLayoutSpecs
{
  __shouldVisualizeLayoutSpecs = shouldVisualizeLayoutSpecs;
}

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
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];      // FIXME: need to auto pass properties to children
  insetSpec.neverShouldVisualize = YES;
  self.layoutSpec.neverShouldVisualize = YES;
  UIEdgeInsets insets = UIEdgeInsetsZero; //UIEdgeInsetsMake(10, 10, 10, 10);
  
  // propogate child's layoutSpec properties to the inset that we are adding
  insetSpec.flexGrow = _layoutSpec.flexGrow;
  insetSpec.flexShrink = _layoutSpec.flexShrink;
  insetSpec.alignSelf = _layoutSpec.alignSelf;
  
  insetSpec.insets = insets;
  insetSpec.child = self.layoutSpec;
  return self.layoutSpec;
}

- (void)layoutMagicNodeTapped:(UIGestureRecognizer *)sender
{
  [[ASLayoutableInspectorNode sharedInstance] setLayoutableToEdit:self.layoutSpec];
}

@end


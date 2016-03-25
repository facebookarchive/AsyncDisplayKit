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
    self.layer.borderWidth = 2;
    self.layoutSpec = layoutSpec;
    self.usesImplicitHierarchyManagement = YES;
    self.layer.borderColor = [[UIColor redColor] CGColor];
    
    [self addTarget:self action:@selector(layoutMagicNodeTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];      // FIXME: need to auto pass properties to children
  insetSpec.neverShouldVisualize = YES;
  self.layoutSpec.neverShouldVisualize = YES;
  CGFloat insetFloat = [ASLayoutableInspectorNode sharedInstance].vizNodeInsetSize;
  UIEdgeInsets insets = UIEdgeInsetsMake(insetFloat, insetFloat, insetFloat, insetFloat);
//  UIEdgeInsets insets = UIEdgeInsetsZero;
  
  // propogate child's layoutSpec properties to the inset that we are adding
  insetSpec.flexGrow   = _layoutSpec.flexGrow;              // FIXME:
  insetSpec.flexShrink = _layoutSpec.flexShrink;
  insetSpec.alignSelf  = _layoutSpec.alignSelf;
  insetSpec.insets     = insets;
  insetSpec.child      = self.layoutSpec;
  
  return insetSpec; //self.layoutSpec;
}

- (void)setLayoutSpec:(ASLayoutSpec *)layoutSpec
{
  _layoutSpec = layoutSpec;
  
//  self.flexGrow   = _layoutSpec.flexGrow;
//  self.flexShrink = _layoutSpec.flexShrink;
//  self.alignSelf  = _layoutSpec.alignSelf;
  
  if ([layoutSpec isKindOfClass:[ASInsetLayoutSpec class]]) {
    self.layer.borderColor = [[UIColor redColor] CGColor];
    
  } else if ([layoutSpec isKindOfClass:[ASStackLayoutSpec class]]) {
    self.layer.borderColor = [[UIColor greenColor] CGColor];

  }
}

- (void)layoutMagicNodeTapped:(UIGestureRecognizer *)sender
{
  [[ASLayoutableInspectorNode sharedInstance] setLayoutableToEdit:self.layoutSpec];
}

- (NSString *)description
{
  return [self.layoutSpec description];         // FIXME: expand on layoutSpec description (e.g. have StackLayoutSpec return horz/vert)
}

@end


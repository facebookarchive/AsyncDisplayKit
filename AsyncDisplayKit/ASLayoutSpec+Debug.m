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

@implementation ASLayoutSpecVisualizerNode

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec
{
  self = [super init];
  if (self) {
    self.layer.borderWidth = 2;
    self.layer.borderColor = [[UIColor redColor] CGColor];
    self.layoutSpec = layoutSpec;
    self.layoutSpec.neverShouldVisualize = YES;
    self.usesImplicitHierarchyManagement = YES;
    self.shouldCacheLayoutSpec = YES;
    [self addTarget:self action:@selector(visualizerNodeTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGFloat insetFloat   = [ASLayoutableInspectorNode sharedInstance].vizNodeInsetSize;
  UIEdgeInsets insets  = UIEdgeInsetsMake(insetFloat, insetFloat, insetFloat, insetFloat);
  
  // FIXME in framework: auto pass properties to children
  ASInsetLayoutSpec *insetSpec   = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:self.layoutSpec];
  insetSpec.neverShouldVisualize = YES;

  // propogate child's layoutSpec properties to the inset that we are adding
//  insetSpec.flexGrow   = _layoutSpec.flexGrow;
//  insetSpec.flexShrink = _layoutSpec.flexShrink;
//  insetSpec.alignSelf  = _layoutSpec.alignSelf;
  
  NSLog(@"%@: vizNode = %d, child = %d", self, insetSpec.flexGrow, _layoutSpec.flexGrow);
  
  return insetSpec;
}

- (void)setLayoutSpec:(ASLayoutSpec *)layoutSpec  // FIXME: this is duplicated in InspectorNode - make it a category on ASLayoutSpec?
{
  _layoutSpec = layoutSpec;                       // FIXME: should copy layoutSpec properities to self?
  
  if ([layoutSpec isKindOfClass:[ASInsetLayoutSpec class]]) {
    self.layer.borderColor = [[UIColor redColor] CGColor];
    
  } else if ([layoutSpec isKindOfClass:[ASStackLayoutSpec class]]) {
    self.layer.borderColor = [[UIColor greenColor] CGColor];

  }
}

- (NSString *)description
{
  return [self.layoutSpec description];   // FIXME: expand on layoutSpec description (e.g. have StackLayoutSpec return horz/vert)
}

- (void)visualizerNodeTapped:(UIGestureRecognizer *)sender
{
  [[ASLayoutableInspectorNode sharedInstance] setLayoutableToEdit:self.layoutSpec];
}

@end


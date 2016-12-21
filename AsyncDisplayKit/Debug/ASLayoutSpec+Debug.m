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
#import "ASLayoutElementInspectorNode.h"

@implementation ASLayoutSpecVisualizerNode

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec
{
  self = [super init];
  if (self) {
    self.borderWidth = 2;
    self.borderColor = [[UIColor redColor] CGColor];
    self.layoutSpec = layoutSpec;
    self.layoutSpec.neverShouldVisualize = YES;
    self.automaticallyManagesSubnodes = YES;
    self.shouldCacheLayoutSpec = YES;
    [self addTarget:self action:@selector(visualizerNodeTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGFloat insetFloat   = [ASLayoutElementInspectorNode sharedInstance].vizNodeInsetSize;
  UIEdgeInsets insets  = UIEdgeInsetsMake(insetFloat, insetFloat, insetFloat, insetFloat);
  
  // FIXME in framework: auto pass properties to children
  ASInsetLayoutSpec *insetSpec   = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:self.layoutSpec];
  insetSpec.neverShouldVisualize = YES;

  // propogate child's layoutSpec properties to the inset that we are adding
//  insetSpec.style.flexGrow   = _layoutSpec.style.flexGrow;
//  insetSpec.style.flexShrink = _layoutSpec.style.flexShrink;
//  insetSpec.alignSelf  = _layoutSpec.alignSelf;
  
//  NSLog(@"%@: vizNode = %f, child = %f", self, insetSpec.style.flexGrow, _layoutSpec.style.flexGrow);
  
  return insetSpec;
}

- (void)setLayoutSpec:(ASLayoutSpec *)layoutSpec  // FIXME: this is duplicated in InspectorNode - make it a category on ASLayoutSpec?
{
  _layoutSpec = layoutSpec;                       // FIXME: should copy layoutSpec properities to self?
  
  if ([layoutSpec isKindOfClass:[ASInsetLayoutSpec class]]) {
    self.borderColor = [[UIColor redColor] CGColor];
    
  } else if ([layoutSpec isKindOfClass:[ASStackLayoutSpec class]]) {
    self.borderColor = [[UIColor greenColor] CGColor];
  }
}

- (NSString *)description
{
  return [self.layoutSpec description];   // FIXME: expand on layoutSpec description (e.g. have StackLayoutSpec return horz/vert)
}

- (void)visualizerNodeTapped:(UIGestureRecognizer *)sender
{
  [[ASLayoutElementInspectorNode sharedInstance] setLayoutElementToEdit:self.layoutSpec];
}

@end


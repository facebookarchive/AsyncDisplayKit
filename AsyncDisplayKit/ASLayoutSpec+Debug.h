//
//  ASLayoutSpec+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/20/16.
//
//

#import "ASLayoutSpec.h"

@interface ASLayoutSpec (Debugging)

@end


@interface ASLayoutSpecMagicNode : ASControlNode

@property (nonatomic, strong) ASLayoutSpec *layoutSpec;

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec;

@end

@implementation ASLayoutSpecMagicNode

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec
{
  self = [super init];
  if (self) {
    self.layoutSpec = layoutSpec;
    self.usesImplicitHierarchyManagement = YES;
    self.layer.borderColor = [[UIColor redColor] CGColor];
    self.layer.borderWidth = 2;
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
  insetSpec.neverMagicNode = YES;
  self.layoutSpec.neverMagicNode = YES;
  UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
  insetSpec.insets = insets;
  insetSpec.child = self.layoutSpec;
  return insetSpec;
}


@end
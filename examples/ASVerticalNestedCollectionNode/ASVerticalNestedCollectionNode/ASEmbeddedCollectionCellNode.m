//
//  ASEmbeddedCollectionCellNode.m
//  ASVerticalCollecttionNode
//
//  Created by Kieran Lafferty on 12/21/15.
//  Copyright © 2015 Kieran Lafferty. All rights reserved.
//

#import "ASEmbeddedCollectionCellNode.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@implementation ASEmbeddedCollectionCellNode

- (nonnull instancetype)initWithCollectionNode:(nonnull ASCollectionNode *)collectionNode
{
    if (self = [super init]) {
        _collectionNode = collectionNode;
        [self addSubnode:_collectionNode];
    }
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStaticLayoutSpec *staticCollectionNodeSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[_collectionNode]];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:staticCollectionNodeSpec];
}

@end

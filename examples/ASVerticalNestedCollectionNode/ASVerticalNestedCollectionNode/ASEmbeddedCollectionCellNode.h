//
//  ASEmbeddedCollectionCellNode.h
//  ASVerticalCollecttionNode
//
//  Created by Kieran Lafferty on 12/21/15.
//  Copyright © 2015 Kieran Lafferty. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASEmbeddedCollectionCellNode : ASCellNode

- (nonnull instancetype)initWithCollectionNode:(nonnull ASCollectionNode *)collectionNode;

@property (nonatomic, strong, readonly, nonnull) ASCollectionNode *collectionNode;

@end

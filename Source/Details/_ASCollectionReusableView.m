//
//  _ASCollectionReusableView.m
//  AsyncDisplayKit
//
//  Created by Phil Larson on 4/10/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "_ASCollectionReusableView.h"
#import "ASCellNode+Internal.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@implementation _ASCollectionReusableView

- (void)setNode:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  node.layoutAttributes = _layoutAttributes;
  _node = node;
}

- (void)setLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  _layoutAttributes = layoutAttributes;
  _node.layoutAttributes = layoutAttributes;
}

- (void)prepareForReuse
{
  self.layoutAttributes = nil;
  
  // Need to clear node pointer before UIKit calls setSelected:NO / setHighlighted:NO on its cells
  self.node = nil;
  [super prepareForReuse];
}

/**
 * In the initial case, this is called by UICollectionView during cell dequeueing, before
 *   we get a chance to assign a node to it, so we must be sure to set these layout attributes
 *   on our node when one is next assigned to us in @c setNode: . Since there may be cases when we _do_ already
 *   have our node assigned e.g. during a layout update for existing cells, we also attempt
 *   to update it now.
 */
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  self.layoutAttributes = layoutAttributes;
}

/**
 * Keep our node filling our content view.
 */
- (void)layoutSubviews
{
  [super layoutSubviews];
  self.node.frame = self.bounds;
}

@end

/**
 * A category that makes _ASCollectionReusableView conform to IGListBindable.
 *
 * We don't need to do anything to bind the view model – the cell node
 * serves the same purpose.
 */
#if __has_include(<IGListKit/IGListBindable.h>)

#import <IGListKit/IGListBindable.h>

@interface _ASCollectionReusableView (IGListBindable) <IGListBindable>
@end

@implementation _ASCollectionReusableView (IGListBindable)

- (void)bindViewModel:(id)viewModel
{
  // nop
}

@end

#endif

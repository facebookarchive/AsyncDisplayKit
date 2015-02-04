/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASDisplayNode.h>

/**
 * Generic cell node.  Subclass ASCellNode instead of <ASDisplayNode> to use <ASTableView>.
 */
@interface ASCellNode : ASDisplayNode

/*
 * ASTableView uses these properties when configuring UITableViewCells that host ASCellNodes.
 */
//@property (atomic, retain) UIColor *backgroundColor;
@property (nonatomic) UITableViewCellSelectionStyle selectionStyle;

/**
 * @abstract Returns the UICollectionViewCell or UITableViewCell if the node is currently
 * visible in either a ASCollectionView or ASTableView, respectively.
 *
 * @discussion Assumes the ASCellNode is being used with an ASCollectionView or ASTableView.
 */
@property (nonatomic, readonly, retain) UIView *cellView;

@end


/**
 * Simple label-style cell node.  Read its source for an example of custom <ASCellNode>s.
 */
@interface ASTextCellNode : ASCellNode

/**
 * Text to display.
 */
@property (nonatomic, copy) NSString *text;

@end

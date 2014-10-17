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

// TODO expose some UITableViewCell properties for configuration, eg, separator style

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

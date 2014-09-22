/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASDisplayNode.h>

@interface ASCellNode : ASDisplayNode

// TODO expose some UITableViewCell things for configuration, eg, separator style

@end


@interface ASTextCellNode : ASCellNode

@property (nonatomic, copy) NSString *text;

@end

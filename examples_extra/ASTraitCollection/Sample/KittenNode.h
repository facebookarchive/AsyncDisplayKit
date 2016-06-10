//
//  KittenNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface KittenNode : ASCellNode
@property (nonatomic, strong, readonly) ASNetworkImageNode *imageNode;
@property (nonatomic, strong, readonly) ASTextNode *textNode;

@property (nonatomic, copy) dispatch_block_t imageTappedBlock;

// The default action when an image node is tapped. This action will create an
// OverrideVC and override its display traits to always be compact.
+ (void)defaultImageTappedAction:(ASViewController *)sourceViewController;
@end

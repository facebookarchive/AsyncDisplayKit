//
//  ScreenNode.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ScreenNode : ASDisplayNode

@property (nonatomic, strong) ASMultiplexImageNode *imageNode;
@property (nonatomic, strong) ASButtonNode *buttonNode;

- (void)start;
- (void)reload;

@end

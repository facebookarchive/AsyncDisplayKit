//
//  ASDisplayNodeTestsHelper.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASDimension.h>

@class ASDisplayNode;

typedef BOOL (^as_condition_block_t)(void);

ASDISPLAYNODE_EXTERN_C_BEGIN

BOOL ASDisplayNodeRunRunLoopUntilBlockIsTrue(as_condition_block_t block);

void ASDisplayNodeSizeToFitSize(ASDisplayNode *node, CGSize size);
void ASDisplayNodeSizeToFitSizeRange(ASDisplayNode *node, ASSizeRange sizeRange);

ASDISPLAYNODE_EXTERN_C_END

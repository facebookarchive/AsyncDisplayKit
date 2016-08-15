//
//  ASTextNodeSnapshotTests.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 8/12/16.
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASSnapshotTestCase.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASTextNodeSnapshotTests : ASSnapshotTestCase

@end

@implementation ASTextNodeSnapshotTests

- (void)testTextContainerInset
{
  // trivial test case to ensure ASSnapshotTestCase works
  ASTextNode *textNode = [[ASTextNode alloc] init];
  textNode.attributedText = [[NSAttributedString alloc] initWithString:@"judar"
                                                            attributes:@{NSFontAttributeName : [UIFont italicSystemFontOfSize:24]}];
  [textNode measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX))];
  textNode.frame = CGRectMake(0, 0, textNode.calculatedSize.width, textNode.calculatedSize.height);
  textNode.textContainerInset = UIEdgeInsetsMake(0, 2, 0, 2);
  
  ASSnapshotVerifyNode(textNode, nil);
}

@end

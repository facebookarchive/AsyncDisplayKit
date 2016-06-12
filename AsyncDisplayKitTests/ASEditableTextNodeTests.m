//
//  ASEditableTextNodeTests.m
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 5/31/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASEditableTextNode.h>

static BOOL CGSizeEqualToSizeWithIn(CGSize size1, CGSize size2, CGFloat delta)
{
  return fabs(size1.width - size2.width) < delta && fabs(size1.height - size2.height) < delta;
}

@interface ASEditableTextNodeTests : XCTestCase
@property (nonatomic, readwrite, strong) ASEditableTextNode *editableTextNode;
@property (nonatomic, readwrite, copy) NSAttributedString *attributedText;
@end

@implementation ASEditableTextNodeTests

- (void)setUp
{
  [super setUp];
  
  _editableTextNode = [[ASEditableTextNode alloc] init];
  
  NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."];
  NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
  para.alignment = NSTextAlignmentCenter;
  para.lineSpacing = 1.0;
  [mas addAttribute:NSParagraphStyleAttributeName value:para
              range:NSMakeRange(0, mas.length - 1)];
  
  // Vary the linespacing on the last line
  NSMutableParagraphStyle *lastLinePara = [NSMutableParagraphStyle new];
  lastLinePara.alignment = para.alignment;
  lastLinePara.lineSpacing = 5.0;
  [mas addAttribute:NSParagraphStyleAttributeName value:lastLinePara
              range:NSMakeRange(mas.length - 1, 1)];
  
  _attributedText = mas;
  _editableTextNode.attributedText = _attributedText;

}

#pragma mark - ASEditableTextNode

- (void)testAllocASEditableTextNode
{
  ASEditableTextNode *node = [[ASEditableTextNode alloc] init];
  XCTAssertTrue([[node class] isSubclassOfClass:[ASEditableTextNode class]], @"ASTextNode alloc should return an instance of ASTextNode, instead returned %@", [node class]);
}

#pragma mark - ASEditableTextNode

- (void)testSetPreferredFrameSize
{
  CGSize preferredFrameSize = CGSizeMake(100, 100);
  _editableTextNode.preferredFrameSize = preferredFrameSize;
  
  CGSize calculatedSize = [_editableTextNode measure:CGSizeZero];
  XCTAssertTrue(calculatedSize.width != preferredFrameSize.width, @"Calculated width (%f) should be equal than preferred width (%f)", calculatedSize.width, preferredFrameSize.width);
  XCTAssertTrue(calculatedSize.width != preferredFrameSize.width, @"Calculated height (%f) should be equal than preferred height (%f)", calculatedSize.width, preferredFrameSize.width);
  
  _editableTextNode.preferredFrameSize = CGSizeZero;
}

- (void)testCalculatedSizeIsGreaterThanOrEqualToConstrainedSize
{
  for (NSInteger i = 10; i < 500; i += 50) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_editableTextNode measure:constrainedSize];
    XCTAssertTrue(calculatedSize.width <= constrainedSize.width, @"Calculated width (%f) should be less than or equal to constrained width (%f)", calculatedSize.width, constrainedSize.width);
    XCTAssertTrue(calculatedSize.height <= constrainedSize.height, @"Calculated height (%f) should be less than or equal to constrained height (%f)", calculatedSize.height, constrainedSize.height);
  }
}

- (void)testRecalculationOfSizeIsSameAsOriginallyCalculatedSize
{
  for (NSInteger i = 10; i < 500; i += 50) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_editableTextNode measure:constrainedSize];
    CGSize recalculatedSize = [_editableTextNode measure:calculatedSize];
    
    XCTAssertTrue(CGSizeEqualToSizeWithIn(calculatedSize, recalculatedSize, 4.0), @"Recalculated size %@ should be same as original size %@", NSStringFromCGSize(recalculatedSize), NSStringFromCGSize(calculatedSize));
  }
}

- (void)testRecalculationOfSizeIsSameAsOriginallyCalculatedFloatingPointSize
{
  for (CGFloat i = 10; i < 500; i *= 1.3) {
    CGSize constrainedSize = CGSizeMake(i, i);
    CGSize calculatedSize = [_editableTextNode measure:constrainedSize];
    CGSize recalculatedSize = [_editableTextNode measure:calculatedSize];

    XCTAssertTrue(CGSizeEqualToSizeWithIn(calculatedSize, recalculatedSize, 11.0), @"Recalculated size %@ should be same as original size %@", NSStringFromCGSize(recalculatedSize), NSStringFromCGSize(calculatedSize));
  }
}

@end

/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <FBSnapshotTestCase/FBSnapshotTestController.h>

#import "ASTextKitAttributes.h"
#import "ASTextKitRenderer.h"

@interface ASTextKitTests : XCTestCase

@end

static UITextView *UITextViewWithAttributes(const ASTextKitAttributes &attributes, const CGSize constrainedSize)
{
  UITextView *textView = [[UITextView alloc] initWithFrame:{ .size = constrainedSize }];
  textView.backgroundColor = [UIColor clearColor];
  textView.textContainer.lineBreakMode = attributes.lineBreakMode;
  textView.textContainer.lineFragmentPadding = 0.f;
  textView.textContainer.maximumNumberOfLines = attributes.maximumNumberOfLines;
  textView.textContainerInset = UIEdgeInsetsZero;
  textView.layoutManager.usesFontLeading = NO;
  textView.attributedText = attributes.attributedString;
  return textView;
}

static UIImage *UITextViewImageWithAttributes(const ASTextKitAttributes &attributes, const CGSize constrainedSize)
{
  UITextView *textView = UITextViewWithAttributes(attributes, constrainedSize);
  UIGraphicsBeginImageContextWithOptions(constrainedSize, NO, 0);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  CGContextSaveGState(context);
  {
    [textView.layer renderInContext:context];
  }
  CGContextRestoreGState(context);
  
  UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return snapshot;
}

static UIImage *ASTextKitImageWithAttributes(const ASTextKitAttributes &attributes, const CGSize constrainedSize)
{
  ASTextKitRenderer *renderer = [[ASTextKitRenderer alloc] initWithTextKitAttributes:attributes
                                                                     constrainedSize:constrainedSize];
  UIGraphicsBeginImageContextWithOptions(constrainedSize, NO, 0);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  CGContextSaveGState(context);
  {
    [renderer drawInContext:context bounds:{.size = constrainedSize}];
  }
  CGContextRestoreGState(context);
  
  UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return snapshot;
}

static BOOL checkAttributes(const ASTextKitAttributes &attributes, const CGSize constrainedSize)
{
  FBSnapshotTestController *controller = [[FBSnapshotTestController alloc] init];
  UIImage *labelImage = UITextViewImageWithAttributes(attributes, constrainedSize);
  UIImage *textKitImage = ASTextKitImageWithAttributes(attributes, constrainedSize);
  return [controller compareReferenceImage:labelImage toImage:textKitImage error:nil];
}

@implementation ASTextKitTests

- (void)testSimpleStrings
{
  ASTextKitAttributes attributes {
    .attributedString = [[NSAttributedString alloc] initWithString:@"hello" attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12]}]
  };
  XCTAssert(checkAttributes(attributes, { 100, 100 }));
}

- (void)testChangingAPropertyChangesHash
{
  NSAttributedString *as = [[NSAttributedString alloc] initWithString:@"hello" attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12]}];
  
  ASTextKitAttributes attrib1 {
    .attributedString = as,
    .lineBreakMode =  NSLineBreakByClipping,
  };
  ASTextKitAttributes attrib2 {
    .attributedString = as,
  };
  
  XCTAssertNotEqual(attrib1.hash(), attrib2.hash(), @"Hashes should differ when NSLineBreakByClipping changes.");
}

- (void)testSameStringHashesSame
{
  ASTextKitAttributes attrib1 {
    .attributedString = [[NSAttributedString alloc] initWithString:@"hello" attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12]}],
  };
  ASTextKitAttributes attrib2 {
    .attributedString = [[NSAttributedString alloc] initWithString:@"hello" attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12]}],
  };
  
  XCTAssertEqual(attrib1.hash(), attrib2.hash(), @"Hashes should be the same!");
}


- (void)testStringsWithVariableAttributes
{
  NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:@"hello" attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:12]}];
  for (int i = 0; i < attrStr.length; i++) {
    // Color each character something different
    CGFloat factor = ((CGFloat)i) / ((CGFloat)attrStr.length);
    [attrStr addAttribute:NSForegroundColorAttributeName
                    value:[UIColor colorWithRed:factor
                                          green:1.0 - factor
                                           blue:0.0
                                          alpha:1.0]
                    range:NSMakeRange(i, 1)];
  }
  ASTextKitAttributes attributes {
    .attributedString = attrStr
  };
  XCTAssert(checkAttributes(attributes, { 100, 100 }));
}

@end

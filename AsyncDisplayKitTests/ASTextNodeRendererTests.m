/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <XCTest/XCTest.h>

#import "ASTextNodeRenderer.h"

@interface ASTextNodeRendererTests : XCTestCase

@property (nonatomic, readwrite, strong) ASTextNodeRenderer *renderer;
@property (nonatomic, copy, readwrite) NSAttributedString *attributedString;
@property (nonatomic, copy, readwrite) NSAttributedString *truncationString;
@property (nonatomic, readwrite, assign) NSLineBreakMode truncationMode;
@property (nonatomic, readwrite, assign) NSUInteger maximumLineCount;
@property (nonatomic, readwrite, assign) CGFloat lineSpacing;

@property (nonatomic, readwrite, assign) CGSize constrainedSize;
@property (nonatomic, readwrite) NSArray *exclusionPaths;

@end

@implementation ASTextNodeRendererTests

- (void)setUp
{
  [super setUp];

  _truncationMode = NSLineBreakByWordWrapping;

  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  _lineSpacing = 14.0;
  paragraphStyle.lineSpacing = _lineSpacing;
  paragraphStyle.maximumLineHeight = _lineSpacing;
  paragraphStyle.minimumLineHeight = _lineSpacing;
  NSDictionary *attributes = @{ NSFontAttributeName : [UIFont systemFontOfSize:12.0],
                                NSParagraphStyleAttributeName : paragraphStyle };
  _attributedString = [[NSAttributedString alloc] initWithString:@"Lorem ipsum" attributes:attributes];
  _truncationString = [[NSAttributedString alloc] initWithString:@"More"];

  _exclusionPaths = nil;

  _constrainedSize = CGSizeMake(FLT_MAX, FLT_MAX);
}

- (void)setUpRenderer
{
  _renderer = [[ASTextNodeRenderer alloc] initWithAttributedString:_attributedString
                                                      truncationString:_truncationString
                                                        truncationMode:_truncationMode
                                                      maximumLineCount:_maximumLineCount
                                                        exclusionPaths:_exclusionPaths
                                                       constrainedSize:_constrainedSize];

}

- (void)testCalculateSize
{
  [self setUpRenderer];

  CGSize size = [_renderer size];
  XCTAssertTrue(size.width > 0, @"Should have a nonzero width");
  XCTAssertTrue(size.height > 0, @"Should have a nonzero height");
}

- (void)testNumberOfLines
{
  [self setUpRenderer];
  CGSize size = [_renderer size];
  NSInteger numberOfLines = size.height / _lineSpacing;
  XCTAssertTrue(numberOfLines == 1 , @"If constrained height (%f) is float max, then there should only be one line of text. Size %@", _constrainedSize.width, NSStringFromCGSize(size));
}

- (void)testMaximumLineCount
{
    NSArray *lines = [NSArray arrayWithObjects:@"Hello!", @"world!", @"foo", @"bar", @"baz", nil];
    _maximumLineCount = 2;
    for (int i = 0; i <= [lines count]; i++) {
        NSString *line = [[lines subarrayWithRange:NSMakeRange(0, i)] componentsJoinedByString:@"\n"];
        _attributedString   = [[NSAttributedString alloc] initWithString:line];
        [self setUpRenderer];
        [_renderer size];
        XCTAssertTrue(_renderer.lineCount <= _maximumLineCount, @"The line count %tu after rendering should be no larger than the maximum line count %tu", _renderer.lineCount, _maximumLineCount);
    }
}

- (void)testNoTruncationIfEnoughSpace
{
  [self setUpRenderer];
  [_renderer size];
  NSRange stringRange = NSMakeRange(0, _attributedString.length);
  NSRange visibleRange = [_renderer visibleRange];
  XCTAssertTrue(NSEqualRanges(stringRange, visibleRange), @"There should be no truncation if the text has plenty of space to lay out");
  XCTAssertTrue(NSEqualRanges([_renderer truncationStringCharacterRange], NSMakeRange(NSNotFound, _truncationString.length)), @"There should be no range for the truncation string if no truncation is occurring");
}

- (void)testTruncation
{
  [self setUpRenderer];
  CGSize calculatedSize = [_renderer size];

  // Make the constrained size just a *little* too small
  _constrainedSize = CGSizeMake(calculatedSize.width - 2, calculatedSize.height);
  _renderer = nil;
  [self setUpRenderer];
  [_renderer size];
  NSRange stringRange = NSMakeRange(0, _attributedString.length);
  NSRange visibleRange = [_renderer visibleRange];
  XCTAssertTrue(visibleRange.length < stringRange.length, @"Some truncation should occur if the constrained size is smaller than the previously calculated bounding size. String length %tu, visible range %@", _attributedString.length, NSStringFromRange(visibleRange));
  NSRange truncationRange = [_renderer truncationStringCharacterRange];
  XCTAssertTrue(truncationRange.location == NSMaxRange(visibleRange), @"Truncation location (%zd) should be after the end of the visible range (%zd)", truncationRange.location, NSMaxRange(visibleRange));
  XCTAssertTrue(truncationRange.length == _truncationString.length, @"Truncation string length (%zd) should be the full length of the supplied truncation string (%@)", truncationRange.length, _truncationString.string);
}

/**
 * We don't want to decrease the total number of lines, i.e. truncate too aggressively,
 * But we also don't want to add extra lines just to display our truncation message
 */
- (void)testTruncationConservesOriginalHeight
{
  [self setUpRenderer];
  CGSize calculatedSize = [_renderer size];

  // Make the constrained size just a *little* too small
  _constrainedSize = CGSizeMake(calculatedSize.width - 1, calculatedSize.height);
  [self setUpRenderer];
  CGSize calculatedSizeWithTruncation = [_renderer size];
  // Floating point equality
  XCTAssertTrue(fabs(calculatedSizeWithTruncation.height - calculatedSize.height) < .001, @"The height after truncation (%f) doesn't match the normal calculated height (%f)", calculatedSizeWithTruncation.height, calculatedSize.height);
}

- (void)testNoCrashOnTappingEmptyTextNode
{
  _attributedString = [[NSAttributedString alloc] initWithString:@""];
  [self setUpRenderer];
  [_renderer size];
  [_renderer enumerateTextIndexesAtPosition:CGPointZero usingBlock:^(NSUInteger characterIndex, CGRect glyphBoundingRect, BOOL *stop) {
    XCTFail(@"Shouldn't be any text indexes to enumerate");
  }];
}

- (void)testExclusionPaths
{
  _constrainedSize = CGSizeMake(200, CGFLOAT_MAX);
  [self setUpRenderer];
  CGSize sizeWithoutExclusionPath = [_renderer size];

  CGRect exclusionRect = CGRectMake(20, 0, 180, _lineSpacing * 2.0);
  _exclusionPaths = @[[UIBezierPath bezierPathWithRect:exclusionRect]];
  [self setUpRenderer];
  CGSize sizeWithExclusionPath = [_renderer size];

  XCTAssertEqualWithAccuracy(sizeWithoutExclusionPath.height + exclusionRect.size.height, sizeWithExclusionPath.height, 0.5, @"Using an exclusion path so the the text can not fit into the first two lines should increment the size of the text by the heigth of the exclusion path");
}

@end

//
//  ASIndexPath.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASIndexPath.h"

#import <UIKit/UIKit.h>

ASIndexPath ASIndexPathMake(NSInteger section, NSInteger row)
{
  ASIndexPath indexPath;
  indexPath.section = section;
  indexPath.row = row;
  return indexPath;
}

BOOL ASIndexPathEqualToIndexPath(ASIndexPath first, ASIndexPath second)
{
  return (first.section == second.section && first.row == second.row);
}

ASIndexPath ASIndexPathMinimum(ASIndexPath first, ASIndexPath second)
{
  if (first.section < second.section) {
    return first;
  } else if (first.section > second.section) {
    return second;
  } else {
    return (first.row < second.row ? first : second);
  }
}

ASIndexPath ASIndexPathMaximum(ASIndexPath first, ASIndexPath second)
{
  if (first.section > second.section) {
    return first;
  } else if (first.section < second.section) {
    return second;
  } else {
    return (first.row > second.row ? first : second);
  }
}

ASIndexPathRange ASIndexPathRangeMake(ASIndexPath first, ASIndexPath second)
{
  ASIndexPathRange range;
  range.start = ASIndexPathMinimum(first, second);
  range.end = ASIndexPathMaximum(first, second);
  return range;
}

BOOL ASIndexPathRangeEqualToIndexPathRange(ASIndexPathRange first, ASIndexPathRange second)
{
  return ASIndexPathEqualToIndexPath(first.start, second.start) && ASIndexPathEqualToIndexPath(first.end, second.end);
}

@implementation NSIndexPath (ASIndexPathAdditions)

+ (NSIndexPath *)indexPathWithASIndexPath:(ASIndexPath)indexPath
{
  return [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];;
}

- (ASIndexPath)ASIndexPathValue
{
  return ASIndexPathMake(self.section, self.row);
}

@end

//
//  ASIndexPath.h
//  Pods
//
//  Created by Scott Goodson on 7/4/15.
//
//  A much more efficient way to handle index paths than NSIndexPath.
//  For best results, use C++ vectors; NSValue wrapping with Cocoa collections
//  would make NSIndexPath a much better choice.
//

typedef struct {
  NSInteger section;
  NSInteger row;
} ASIndexPath;

typedef struct {
  ASIndexPath start;
  ASIndexPath end;
} ASIndexPathRange;

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

@interface NSIndexPath (ASIndexPathAdditions)
+ (NSIndexPath *)indexPathWithASIndexPath:(ASIndexPath)indexPath;
- (ASIndexPath)ASIndexPathValue;
@end

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

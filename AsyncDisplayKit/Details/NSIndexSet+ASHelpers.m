//
//  NSIndexSet+ASHelpers.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 6/23/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NSIndexSet+ASHelpers.h"

@implementation NSIndexSet (ASHelpers)

- (NSIndexSet *)as_indexesByMapping:(NSUInteger (^)(NSUInteger))block
{
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  [self enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL * _Nonnull stop) {
    NSUInteger newIndex = block(idx);
    if (newIndex != NSNotFound) {
      [result addIndex:newIndex];
    }
  }];
  return result;
}

- (NSIndexSet *)as_intersectionWithIndexes:(NSIndexSet *)indexes
{
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    [indexes enumerateRangesInRange:range options:kNilOptions usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
      [result addIndexesInRange:range];
    }];
  }];
  return result;
}

+ (NSIndexSet *)as_indexSetFromIndexPaths:(NSArray<NSIndexPath *> *)indexPaths inSection:(NSUInteger)section
{
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  for (NSIndexPath *indexPath in indexPaths) {
    if (indexPath.section == section) {
      [result addIndex:indexPath.item];
    }
  }
  return result;
}

- (NSUInteger)as_indexChangeByInsertingItemsBelowIndex:(NSUInteger)index
{
  __block NSUInteger newIndex = index;
  [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    if (idx <= newIndex) {
      newIndex += 1;
    } else {
      *stop = YES;
    }
  }];
  return newIndex - index;
}

- (NSString *)as_smallDescription
{
  NSMutableString *result = [NSMutableString stringWithString:@"{ "];
  [self enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    if (range.length == 1) {
      [result appendFormat:@"%lu ", (unsigned long)range.location];
    } else {
      [result appendFormat:@"%lu-%lu ", (unsigned long)range.location, (unsigned long)NSMaxRange(range)];
    }
  }];
  [result appendString:@"}"];
  return result;
}

@end

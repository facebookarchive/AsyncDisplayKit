//
//  NSArray+Diffing.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "NSArray+Diffing.h"

@implementation NSArray (Diffing)

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions
{
  [self asdk_diffWithArray:array insertions:insertions deletions:deletions compareBlock:^BOOL(id lhs, id rhs) {
    return [lhs isEqual:rhs];
  }];
}

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions compareBlock:(BOOL (^)(id lhs, id rhs))comparison
{
  NSIndexSet *commonIndexes = [self _asdk_commonIndexesWithArray:array compareBlock:comparison];
  
  if (insertions) {
    NSArray *commonObjects = [self objectsAtIndexes:commonIndexes];
    NSMutableIndexSet *insertionIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = 0, j = 0; i < commonObjects.count || j < array.count;) {
      if (i < commonObjects.count && j < array.count && comparison(commonObjects[i], array[j])) {
        i++; j++;
      } else {
        [insertionIndexes addIndex:j];
        j++;
      }
    }
    *insertions = insertionIndexes;
  }
  
  if (deletions) {
    NSMutableIndexSet *deletionIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = 0; i < self.count; i++) {
      if (![commonIndexes containsIndex:i]) {
        [deletionIndexes addIndex:i];
      }
    }
    *deletions = deletionIndexes;
  }
}

- (NSIndexSet *)_asdk_commonIndexesWithArray:(NSArray *)array compareBlock:(BOOL (^)(id lhs, id rhs))comparison
{
  NSInteger lengths[self.count+1][array.count+1];
  for (NSInteger i = self.count; i >= 0; i--) {
    for (NSInteger j = array.count; j >= 0; j--) {
      if (i == self.count || j == array.count) {
        lengths[i][j] = 0;
      } else if ([self[i] isEqual:array[j]]) {
        lengths[i][j] = 1 + lengths[i+1][j+1];
      } else {
        lengths[i][j] = MAX(lengths[i+1][j], lengths[i][j+1]);
      }
    }
  }
  
  NSMutableIndexSet *common = [NSMutableIndexSet indexSet];
  for (NSInteger i = 0, j = 0; i < self.count && j < array.count;) {
    if (comparison(self[i], array[j])) {
      [common addIndex:i];
      i++; j++;
    } else if (lengths[i+1][j] >= lengths[i][j+1]) {
      i++;
    } else {
      j++;
    }
  }
  return common;
}

@end

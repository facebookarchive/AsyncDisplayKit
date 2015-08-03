/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <Foundation/Foundation.h>

typedef struct {
  NSInteger section;
  NSInteger row;
} ASIndexPath;

typedef struct {
  ASIndexPath start;
  ASIndexPath end;
} ASIndexPathRange;

ASDISPLAYNODE_EXTERN_C_BEGIN

extern ASIndexPath ASIndexPathMake(NSInteger section, NSInteger row);

extern BOOL ASIndexPathEqualToIndexPath(ASIndexPath first, ASIndexPath second);

extern ASIndexPath ASIndexPathMinimum(ASIndexPath first, ASIndexPath second);

extern ASIndexPath ASIndexPathMaximum(ASIndexPath first, ASIndexPath second);

extern ASIndexPathRange ASIndexPathRangeMake(ASIndexPath first, ASIndexPath second);

extern BOOL ASIndexPathRangeEqualToIndexPathRange(ASIndexPathRange first, ASIndexPathRange second);

ASDISPLAYNODE_EXTERN_C_END

@interface NSIndexPath (ASIndexPathAdditions)

+ (NSIndexPath *)indexPathWithASIndexPath:(ASIndexPath)indexPath;
- (ASIndexPath)ASIndexPathValue;

@end

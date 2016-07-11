//
//  ASStaticLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASStaticLayoutSpec.h"

#import "ASLayoutSpecUtilities.h"
#import "ASLayout.h"

@implementation ASStaticLayoutSpec

+ (instancetype)staticLayoutSpecWithChildren:(NSArray *)children
{
  return [[self alloc] initWithChildren:children];
}

- (instancetype)init
{
    return [self initWithChildren:@[]];
}

- (instancetype)initWithChildren:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }
  self.children = children;
  return self;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  CGSize maxConstrainedSize = CGSizeMake(constrainedSize.max.width, constrainedSize.max.height);
  
  NSArray *children = self.children;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:children.count];

  for (id<ASLayoutable> child in children) {
    CGPoint layoutPosition = child.layoutPosition;
    CGSize autoMaxSize = CGSizeMake(maxConstrainedSize.width  - layoutPosition.x,
                                    maxConstrainedSize.height - layoutPosition.y);
    
    ASRelativeSizeRange childSizeRange = child.sizeRange;
    BOOL childIsUnconstrained = ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRangeUnconstrained, childSizeRange);
    ASSizeRange childConstraint = childIsUnconstrained ? ASSizeRangeMake({0, 0}, autoMaxSize)
                                                       : ASRelativeSizeRangeResolve(childSizeRange, maxConstrainedSize);
    
    ASLayout *sublayout = [child measureWithSizeRange:childConstraint];
    sublayout.position = layoutPosition;
    [sublayouts addObject:sublayout];
  }
  
  CGSize size = CGSizeMake(constrainedSize.min.width, constrainedSize.min.height);

  for (ASLayout *sublayout in sublayouts) {
    CGPoint sublayoutPosition = sublayout.position;
    CGSize  sublayoutSize     = sublayout.size;
    
    size.width  = MAX(size.width,  sublayoutPosition.x + sublayoutSize.width);
    size.height = MAX(size.height, sublayoutPosition.y + sublayoutSize.height);
  }

  return [ASLayout layoutWithLayoutableObject:self
                         constrainedSizeRange:constrainedSize
                                         size:ASSizeRangeClamp(constrainedSize, size)
                                   sublayouts:sublayouts];
}

@end

@implementation ASStaticLayoutSpec (ASEnvironment)

- (BOOL)supportsUpwardPropagation
{
  return NO;
}

@end

@implementation ASStaticLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)debugBoxString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName]];
}

@end

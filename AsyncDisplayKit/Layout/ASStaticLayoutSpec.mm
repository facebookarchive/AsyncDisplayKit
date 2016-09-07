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

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  // TODO: layout: isValidForLayout() call should not be necessary if INFINITY is used
  CGSize size = {
    (isinf(constrainedSize.max.width) || !ASPointsAreValidForLayout(constrainedSize.max.width)) ? ASLayoutableParentDimensionUndefined : constrainedSize.max.width,
    (isinf(constrainedSize.max.height) || !ASPointsAreValidForLayout(constrainedSize.max.height)) ? ASLayoutableParentDimensionUndefined : constrainedSize.max.height
  };
  
  NSArray *children = self.children;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:children.count];

  for (id<ASLayoutable> child in children) {
    CGPoint layoutPosition = child.layoutPosition;
    CGSize autoMaxSize = {
      constrainedSize.max.width  - layoutPosition.x,
      constrainedSize.max.height - layoutPosition.y
    };

    const ASSizeRange childConstraint = ASLayoutableSizeResolveAutoSize(child.size, size, {{0,0}, autoMaxSize});
    
    ASLayout *sublayout = [child layoutThatFits:childConstraint parentSize:size];
    sublayout.position = layoutPosition;
    [sublayouts addObject:sublayout];
  }
  
  if (isnan(size.width)) {
    size.width = constrainedSize.min.width;
    for (ASLayout *sublayout in sublayouts) {
      size.width  = MAX(size.width,  sublayout.position.x + sublayout.size.width);
    }
  }
  
  if (isnan(size.height)) {
    size.height = constrainedSize.min.height;
    for (ASLayout *sublayout in sublayouts) {
      size.height = MAX(size.height, sublayout.position.y + sublayout.size.height);
    }
  }
  
  return [ASLayout layoutWithLayoutable:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:sublayouts];
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

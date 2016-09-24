//
//  ASAbsoluteLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASAbsoluteLayoutSpec.h"

#import "ASLayoutSpecUtilities.h"
#import "ASLayout.h"

@implementation ASAbsoluteLayoutSpec

+ (instancetype)absoluteLayoutSpecWithChildren:(NSArray *)children
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
    (isinf(constrainedSize.max.width) || !ASPointsAreValidForLayout(constrainedSize.max.width)) ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.width,
    (isinf(constrainedSize.max.height) || !ASPointsAreValidForLayout(constrainedSize.max.height)) ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.height
  };
  
  NSArray *children = self.children;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:children.count];

  for (id<ASLayoutElement> child in children) {
    CGPoint layoutPosition = child.style.layoutPosition;
    CGSize autoMaxSize = {
      constrainedSize.max.width  - layoutPosition.x,
      constrainedSize.max.height - layoutPosition.y
    };

    const ASSizeRange childConstraint = ASLayoutElementSizeResolveAutoSize(child.style.size, size, {{0,0}, autoMaxSize});
    
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
  
  return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:sublayouts];
}

@end

@implementation ASAbsoluteLayoutSpec (ASEnvironment)

- (BOOL)supportsUpwardPropagation
{
  return NO;
}

@end

@implementation ASAbsoluteLayoutSpec (Debugging)

#pragma mark - ASLayoutElementAsciiArtProtocol

- (NSString *)debugBoxString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName]];
}

@end

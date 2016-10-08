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

#import "ASLayout.h"
#import "ASLayoutSpecUtilities.h"
#import "ASLayoutElementStylePrivate.h"

#pragma mark - ASAbsoluteLayoutSpec

@interface ASAbsoluteLayoutSpec ()

// ASStaticLayoutSpec always adjusted the size of itself based on the children's layoutPositino and size.
// ASAbsoluteLayoutSpec does this only if the constrainedSize.max.width or constrainedSize.max.height is INF.
// For backwards compatiblity let's support both ways
@property (assign, nonatomic) BOOL alwaysSizeToFit;

@end

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

  _alwaysSizeToFit = NO;
  
  self.children = children;
  return self;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  // TODO: layout: isValidForLayout() call should not be necessary if INFINITY is used
  CGSize size = {
    (isinf(constrainedSize.max.width) || !ASPointsValidForLayout(constrainedSize.max.width)) ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.width,
    (isinf(constrainedSize.max.height) || !ASPointsValidForLayout(constrainedSize.max.height)) ? ASLayoutElementParentDimensionUndefined : constrainedSize.max.height
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
  
  if (_alwaysSizeToFit || isnan(size.width)) {
    size.width = constrainedSize.min.width;
    for (ASLayout *sublayout in sublayouts) {
      size.width  = MAX(size.width,  sublayout.position.x + sublayout.size.width);
    }
  }
  
  if (_alwaysSizeToFit || isnan(size.height)) {
    size.height = constrainedSize.min.height;
    for (ASLayout *sublayout in sublayouts) {
      size.height = MAX(size.height, sublayout.position.y + sublayout.size.height);
    }
  }
  
  return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:sublayouts];
}

@end

#pragma mark - ASEnvironment

@implementation ASAbsoluteLayoutSpec (ASEnvironment)

- (BOOL)supportsUpwardPropagation
{
  return NO;
}

@end

#pragma mark - Debugging

@implementation ASAbsoluteLayoutSpec (Debugging)

- (NSString *)debugBoxString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName]];
}

@end


#pragma mark - ASStaticLayoutSpec

@implementation ASStaticLayoutSpec : ASAbsoluteLayoutSpec

+ (instancetype)staticLayoutSpecWithChildren:(NSArray<id<ASLayoutElement>> *)children
{
  return [self absoluteLayoutSpecWithChildren:children];
}

- (instancetype)initWithChildren:(NSArray *)children
{
  if (!(self = [super initWithChildren:children])) {
    return nil;
  }
  
  self.alwaysSizeToFit = YES;
  
  return self;
}

@end

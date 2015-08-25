/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutSpec.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

static NSString * const kDefaultChildKey = @"kDefaultChildKey";
static NSString * const kDefaultChildrenKey = @"kDefaultChildrenKey";

@interface ASLayoutSpec()
@property (nonatomic, strong) NSMutableDictionary *layoutChildren;
@end

@implementation ASLayoutSpec

@synthesize spacingBefore = _spacingBefore;
@synthesize spacingAfter = _spacingAfter;
@synthesize flexGrow = _flexGrow;
@synthesize flexShrink = _flexShrink;
@synthesize flexBasis = _flexBasis;
@synthesize alignSelf = _alignSelf;
@synthesize layoutChildren = _layoutChildren;

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  _layoutChildren = [NSMutableDictionary dictionary];
  _flexBasis = ASRelativeDimensionUnconstrained;
  _isMutable = YES;
  return self;
}

#pragma mark - Layout

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutableObject:self size:constrainedSize.min];
}

- (id<ASLayoutable>)finalLayoutable
{
  return self;
}

- (void)setChild:(id<ASLayoutable>)child;
{
  [self setChild:child forIdentifier:kDefaultChildKey];
}

- (id<ASLayoutable>)child
{
  return self.layoutChildren[kDefaultChildKey];
}

- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  self.layoutChildren[identifier] = [child finalLayoutable];
}

- (id<ASLayoutable>)childForIdentifier:(NSString *)identifier
{
  return self.layoutChildren[identifier];
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  NSMutableArray *finalChildren = [NSMutableArray arrayWithCapacity:children.count];
  for (id<ASLayoutable> child in children) {
    [finalChildren addObject:[child finalLayoutable]];
  }
  self.layoutChildren[kDefaultChildrenKey] = [NSArray arrayWithArray:finalChildren];
}

- (NSArray *)children
{
  return self.layoutChildren[kDefaultChildrenKey];
}

@end

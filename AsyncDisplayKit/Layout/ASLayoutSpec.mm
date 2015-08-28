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
#import "ASLayoutOptions.h"
#import "ASLayoutOptionsPrivate.h"

#import <objc/runtime.h>

static NSString * const kDefaultChildKey = @"kDefaultChildKey";
static NSString * const kDefaultChildrenKey = @"kDefaultChildrenKey";

@interface ASLayoutSpec()
@property (nonatomic, strong) NSMutableDictionary *layoutChildren;
@end

@implementation ASLayoutSpec

@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis, alignSelf, ascender, descender, sizeRange, layoutPosition, layoutOptions;
@synthesize layoutChildren = _layoutChildren;

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  _layoutChildren = [NSMutableDictionary dictionary];
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

- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASLayoutOptions *layoutOptions = [ASLayoutSpec layoutOptionsForChild:child];
  layoutOptions.isMutable = NO;
  self.layoutChildren[identifier] = child;
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  NSMutableArray *finalChildren = [NSMutableArray arrayWithCapacity:children.count];
  for (id<ASLayoutable> child in children) {
    ASLayoutOptions *layoutOptions = [ASLayoutSpec layoutOptionsForChild:child];
    id<ASLayoutable> finalLayoutable = [child finalLayoutable];
    layoutOptions.isMutable = NO;
    
    if (finalLayoutable != child) {
      ASLayoutOptions *finalLayoutOptions = [layoutOptions copy];
      finalLayoutOptions.isMutable = NO;
      [ASLayoutSpec associateLayoutOptions:finalLayoutOptions withChild:finalLayoutable];
      [finalChildren addObject:finalLayoutable];
    } else {
      [finalChildren addObject:child];
    }
  }
  
  self.layoutChildren[kDefaultChildrenKey] = [NSArray arrayWithArray:finalChildren];
}

- (id<ASLayoutable>)childForIdentifier:(NSString *)identifier
{
  return self.layoutChildren[identifier];
}

- (id<ASLayoutable>)child
{
  return self.layoutChildren[kDefaultChildKey];
}

- (NSArray *)children
{
  return self.layoutChildren[kDefaultChildrenKey];
}

static Class gLayoutOptionsClass = [ASLayoutOptions class];
+ (void)setLayoutOptionsClass:(Class)layoutOptionsClass
{
  gLayoutOptionsClass = layoutOptionsClass;
}

+ (ASLayoutOptions *)optionsForChild:(id<ASLayoutable>)child
{
  ASLayoutOptions *layoutOptions = [[gLayoutOptionsClass alloc] init];;
  [layoutOptions setValuesFromLayoutable:child];
  layoutOptions.isMutable = NO;
  return layoutOptions;
}

+ (void)associateLayoutOptions:(ASLayoutOptions *)layoutOptions withChild:(id<ASLayoutable>)child
{
  objc_setAssociatedObject(child, @selector(setChild:), layoutOptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (ASLayoutOptions *)layoutOptionsForChild:(id<ASLayoutable>)child
{
  ASLayoutOptions *layoutOptions = objc_getAssociatedObject(child, @selector(setChild:));
  if (layoutOptions == nil) {
    layoutOptions = [self optionsForChild:child];
    [self associateLayoutOptions:layoutOptions withChild:child];
  }
  return objc_getAssociatedObject(child, @selector(setChild:));
}

                     
                     
@end

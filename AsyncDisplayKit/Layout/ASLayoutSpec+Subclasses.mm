//
//  ASLayoutSpec+Subclasses.m
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 9/15/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutSpec+Subclasses.h"
#import "ASLayoutSpec.h"
#import "ASLayoutSpecPrivate.h"

#pragma mark - ASNullLayoutSpec

@interface ASNullLayoutSpec : ASLayoutSpec
- (instancetype)init __unavailable;
+ (ASNullLayoutSpec *)null;
@end

@implementation ASNullLayoutSpec : ASLayoutSpec

+ (ASNullLayoutSpec *)null
{
  static ASNullLayoutSpec *sharedNullLayoutSpec = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedNullLayoutSpec = [[self alloc] init];
  });
  return sharedNullLayoutSpec;
}

- (BOOL)isMutable
{
  return NO;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutable:self size:CGSizeZero];
}

@end


#pragma mark - ASLayoutSpec (Subclassing)

@implementation ASLayoutSpec (Subclassing)

#pragma mark - Final layoutable

- (id<ASLayoutable>)layoutableToAddFromLayoutable:(id<ASLayoutable>)child
{
  if (self.isFinalLayoutable == NO) {
    id<ASLayoutable> finalLayoutable = [child finalLayoutable];
    if (finalLayoutable != child) {
      if (ASEnvironmentStatePropagationEnabled()) {
        ASEnvironmentStatePropagateUp(finalLayoutable, child.environmentState.layoutOptionsState);
      } else {
        // If state propagation is not enabled the layout options state needs to be copied manually
        ASEnvironmentState finalLayoutableEnvironmentState = finalLayoutable.environmentState;
        finalLayoutableEnvironmentState.layoutOptionsState = child.environmentState.layoutOptionsState;
        finalLayoutable.environmentState = finalLayoutableEnvironmentState;
      }
      return finalLayoutable;
    }
  }
  return child;
}

#pragma mark - Child with index

- (void)setChild:(id<ASLayoutable>)child forIndex:(NSUInteger)index
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  id<ASLayoutable> layoutable = child ? [self layoutableToAddFromLayoutable:child] : [ASNullLayoutSpec null];
  
  if (child) {
    if (_childrenArray.count < index) {
      // Fill up the array with null objects until the index
      NSInteger i = _childrenArray.count;
      while (i < index) {
        _childrenArray[i] = [ASNullLayoutSpec null];
        i++;
      }
    }
  }
  
  // Replace object at the given index with the layoutable
  _childrenArray[index] = layoutable;
  
  // TODO: Should we propagate up the layoutable at it could happen that multiple children will propagated up their
  //       layout options and one child will overwrite values from another child
  // [self propagateUpLayoutable:finalLayoutable];
}

- (id<ASLayoutable>)childForIndex:(NSUInteger)index
{
  id<ASLayoutable> layoutable = nil;
  if (index < _childrenArray.count) {
    layoutable = _childrenArray[index];
  }
  
  // Null layoutable should not be accessed
  ASDisplayNodeAssert(layoutable != [ASNullLayoutSpec null], @"Access child at index without set a child at that index");

  return layoutable;
}

@end

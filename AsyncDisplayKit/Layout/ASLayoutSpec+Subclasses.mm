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
  
  id<ASLayoutable> layoutable = child ? [self layoutableToAddFromLayoutable:child] : [[ASNullLayoutSpec alloc] init];
  
  if (child) {
    if (_childrenArray.count < index) {
      // Fill up the array with null objects until index to fill gaps
      NSInteger i = _childrenArray.count;
      while (i < index) {
        _childrenArray[i] = [[ASNullLayoutSpec alloc] init];
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
  
  // Assert if it's a null layoutable
  ASDisplayNodeAssert([layoutable isKindOfClass:[ASNullLayoutSpec class]] == NO, @"Access child at index without set a child at that index");
  return layoutable;
}

@end

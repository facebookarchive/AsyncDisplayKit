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
#import "ASEnvironmentInternal.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASThread.h"

#import "ASDisplayNode+Subclasses.h" // FIXME: remove this later
#import "ASDisplayNode+Beta.h"       // FIXME: remove this later
#import "ASInsetLayoutSpec.h"        // FIXME: remove this later
#import "ASControlNode.h"            // FIXME: remove this later
#import "ASLayoutSpec+Debug.h"

#import <objc/runtime.h>
#import <vector>

@interface ASLayoutSpec() {
  ASEnvironmentState _environmentState;
  ASDN::RecursiveMutex _propertyLock;
  
  id<ASLayoutable> _child;
  NSArray *_children;
  NSMutableDictionary *_childrenWithIdentifier;
}
@end

@implementation ASLayoutSpec

// these dynamic properties all defined in ASLayoutOptionsPrivate.m
@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis, alignSelf, ascender, descender, sizeRange, layoutPosition;
@synthesize isFinalLayoutable = _isFinalLayoutable;

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  _isMutable = YES;
  _environmentState = ASEnvironmentStateMakeDefault();
  
  return self;
}

#pragma mark - Layout

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutableObject:self size:constrainedSize.min];
}

- (id<ASLayoutable>)finalLayoutable
{
  if (ASLayoutableGetCurrentContext().needsVisualizeNode && !self.neverShouldVisualize) {
    return [[ASLayoutSpecVisualizerNode alloc] initWithLayoutSpec:self];
  } else {
    return self;
  }
}

- (void)recursivelySetShouldVisualize:(BOOL)visualize
{
  NSMutableArray *mutableChildren = [self.children mutableCopy];
  
  for (id<ASLayoutable>layoutableChild in self.children) {
    if ([layoutableChild isKindOfClass:[ASLayoutSpec class]]) {
      ASLayoutSpec *layoutSpec = (ASLayoutSpec *)layoutableChild;
      
      [mutableChildren replaceObjectAtIndex:[mutableChildren indexOfObjectIdenticalTo:layoutSpec]
                                 withObject:[[ASLayoutSpecVisualizerNode alloc] initWithLayoutSpec:layoutSpec]];
      
      [layoutSpec recursivelySetShouldVisualize:visualize];
      layoutSpec.shouldVisualize = visualize;
    }
  }
  
  if ([mutableChildren count] == 1) {         // HACK for wrapper layoutSpecs (e.g. insetLayoutSpec)
    self.child = mutableChildren[0];
  } else if ([mutableChildren count] > 1) {
    self.children = mutableChildren;
  }
}


- (id<ASLayoutable>)layoutableToAddFromLayoutable:(id<ASLayoutable>)child
{
  if (self.isFinalLayoutable == NO) {
    
    // If you are getting recursion crashes here after implementing finalLayoutable, make sure
    // that you are setting isFinalLayoutable flag to YES. This must be one BEFORE adding a child
    // to the new ASLayoutable.
    //
    // For example:
    //- (id<ASLayoutable>)finalLayoutable
    //{
    //  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
    //  insetSpec.insets = UIEdgeInsetsMake(10,10,10,10);
    //  insetSpec.isFinalLayoutable = YES;
    //  [insetSpec setChild:self];
    //  return insetSpec;
    //}

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

- (NSMutableDictionary *)childrenWithIdentifier
{
  if (!_childrenWithIdentifier) {
    _childrenWithIdentifier = [NSMutableDictionary dictionary];
  }
  return _childrenWithIdentifier;
}

- (void)setParent:(id<ASLayoutable>)parent
{
  // FIXME: Locking should be evaluated here.  _parent is not widely used yet, though.
  _parent = parent;
  
  if ([parent supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(parent, self.environmentState.layoutOptionsState);
  }
}

- (void)setChild:(id<ASLayoutable>)child;
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  id<ASLayoutable> finalLayoutable = [self layoutableToAddFromLayoutable:child];
  _child = finalLayoutable;
  [self propagateUpLayoutable:finalLayoutable];
}

- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier                     // FIX
{
  if ([child isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)child setShouldVisualize:self.shouldVisualize];
  }
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  id<ASLayoutable> finalLayoutable = [self layoutableToAddFromLayoutable:child];
  self.childrenWithIdentifier[identifier] = finalLayoutable;
  
  // TODO: Should we propagate up the layoutable at it could happen that multiple children will propagated up their
  //       layout options and one child will overwrite values from another child
  // [self propagateUpLayoutable:finalLayoutable];
}

- (void)setChildren:(NSArray *)children                                                           // FIX
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  std::vector<id<ASLayoutable>> finalChildren;
  for (id<ASLayoutable> child in children) {
    if ([child isKindOfClass:[ASLayoutSpec class]]) {
      [(ASLayoutSpec *)child setShouldVisualize:self.shouldVisualize];
//      NSLog(@"%@ %@ %d", self, child, self.shouldVisualize);
    }
    finalChildren.push_back([self layoutableToAddFromLayoutable:child]);
  }
  
  _children = nil;
  if (finalChildren.size() > 0) {
    _children = [NSArray arrayWithObjects:&finalChildren[0] count:finalChildren.size()];
  }
}

- (id<ASLayoutable>)childForIdentifier:(NSString *)identifier
{
  return self.childrenWithIdentifier[identifier];
}

- (id<ASLayoutable>)child
{
  return _child;
}

- (NSArray *)children
{
  return [_children copy];
}


#pragma mark - ASEnvironment

- (ASEnvironmentState)environmentState
{
  return _environmentState;
}

- (void)setEnvironmentState:(ASEnvironmentState)environmentState
{
  _environmentState = environmentState;
}

// Subclasses can override this method to return NO, because upward propagation is not enabled if a layout
// specification has more than one child. Currently ASStackLayoutSpec and ASStaticLayoutSpec are currently
// the specifications that are known to have more than one.
- (BOOL)supportsUpwardPropagation
{
  return ASEnvironmentStatePropagationEnabled();
}

- (void)propagateUpLayoutable:(id<ASLayoutable>)layoutable
{
  if ([layoutable isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)layoutable setParent:self]; // This will trigger upward propogation if needed.
  } else if ([self supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(self, layoutable.environmentState.layoutOptionsState); // Probably an ASDisplayNode
  }
}

ASEnvironmentLayoutOptionsForwarding
ASEnvironmentLayoutExtensibilityForwarding

@end

@implementation ASLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName direction:(ASStackLayoutDirection)direction
{
  NSMutableArray *childStrings = [NSMutableArray array];
  for (id<ASLayoutableAsciiArtProtocol> layoutChild in children) {
    NSString *childString = [layoutChild asciiArtString];
    if (childString) {
      [childStrings addObject:childString];
    }
  }
  if (direction == ASStackLayoutDirectionHorizontal) {
    return [ASAsciiArtBoxCreator horizontalBoxStringForChildren:childStrings parent:parentName];
  }
  return [ASAsciiArtBoxCreator verticalBoxStringForChildren:childStrings parent:parentName];
}

+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName
{
  return [self asciiArtStringForChildren:children parentName:parentName direction:ASStackLayoutDirectionHorizontal];
}

- (NSString *)asciiArtString
{
  NSArray *children = self.child ? @[self.child] : self.children;
  return [ASLayoutSpec asciiArtStringForChildren:children parentName:[self asciiArtName]];
}

- (NSString *)asciiArtName
{
  return NSStringFromClass([self class]);
}

@end

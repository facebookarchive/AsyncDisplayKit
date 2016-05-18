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
#import "ASTraitCollection.h"

#import <objc/runtime.h>
#import <vector>

@interface ASLayoutSpec() {
  ASEnvironmentState _environmentState;
  ASDN::RecursiveMutex _propertyLock;
  
  id<ASLayoutProducer> _child;
  NSArray *_children;
  NSMutableDictionary *_childrenWithIdentifier;
}
@end

@implementation ASLayoutSpec

// these dynamic properties all defined in ASLayoutOptionsPrivate.m
@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis, alignSelf, ascender, descender, sizeRange, layoutPosition;
@synthesize isFinalLayoutProducer = _isFinalLayoutProducer;

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
  return [ASLayout layoutWithProducer:self size:constrainedSize.min];
}

- (id<ASLayoutProducer>)finalLayoutProducer
{
  return self;
}

- (id<ASLayoutProducer>)layoutProducerToAddFromProducer:(id<ASLayoutProducer>)child
{
  if (self.isFinalLayoutProducer == NO) {
    
    // If you are getting recursion crashes here after implementing finalLayoutProducer, make sure
    // that you are setting isFinalLayoutProducer flag to YES. This must be one BEFORE adding a child
    // to the new ASLayoutProducer.
    //
    // For example:
    //- (id<ASLayoutProducer>)finalLayoutProducer
    //{
    //  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
    //  insetSpec.insets = UIEdgeInsetsMake(10,10,10,10);
    //  insetSpec.isFinalLayoutProducer = YES;
    //  [insetSpec setChild:self];
    //  return insetSpec;
    //}

    id<ASLayoutProducer> finalLayoutProducer = [child finalLayoutProducer];
    if (finalLayoutProducer != child) {
      if (ASEnvironmentStatePropagationEnabled()) {
        ASEnvironmentStatePropagateUp(finalLayoutProducer, child.environmentState.layoutOptionsState);
      } else {
        // If state propagation is not enabled the layout options state needs to be copied manually
        ASEnvironmentState environmentState = finalLayoutProducer.environmentState;
        environmentState.layoutOptionsState = child.environmentState.layoutOptionsState;
        finalLayoutProducer.environmentState = environmentState;
      }
      return finalLayoutProducer;
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

- (void)setParent:(id<ASLayoutProducer>)parent
{
  // FIXME: Locking should be evaluated here.  _parent is not widely used yet, though.
  _parent = parent;
  
  if ([parent supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(parent, self.environmentState.layoutOptionsState);
  }
}

- (void)setChild:(id<ASLayoutProducer>)child;
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  id<ASLayoutProducer> finalLayoutProducer = [self layoutProducerToAddFromProducer:child];
  _child = finalLayoutProducer;
  [self propagateUpLayoutProducer:finalLayoutProducer];
}

- (void)setChild:(id<ASLayoutProducer>)child forIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  id<ASLayoutProducer> finalLayoutProducer = [self layoutProducerToAddFromProducer:child];
  self.childrenWithIdentifier[identifier] = finalLayoutProducer;
  
  // TODO: Should we propagate up the layout producer at it could happen that multiple children will propagated up their
  //       layout options and one child will overwrite values from another child
  // [self propagateUpLayoutProducer:finalLayoutProducer];
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  std::vector<id<ASLayoutProducer>> finalChildren;
  for (id<ASLayoutProducer> child in children) {
    finalChildren.push_back([self layoutProducerToAddFromProducer:child]);
  }
  
  _children = nil;
  if (finalChildren.size() > 0) {
    _children = [NSArray arrayWithObjects:&finalChildren[0] count:finalChildren.size()];
  }
}

- (id<ASLayoutProducer>)childForIdentifier:(NSString *)identifier
{
  return self.childrenWithIdentifier[identifier];
}

- (id<ASLayoutProducer>)child
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

- (BOOL)supportsTraitsCollectionPropagation
{
  return ASEnvironmentStateTraitCollectionPropagationEnabled();
}

- (void)propagateUpLayoutProducer:(id<ASLayoutProducer>)producer
{
  if ([producer isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)producer setParent:self]; // This will trigger upward propogation if needed.
  } else if ([self supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(self, producer.environmentState.layoutOptionsState); // Probably an ASDisplayNode
  }
}

- (ASEnvironmentTraitCollection)environmentTraitCollection
{
  return _environmentState.traitCollection;
}

ASEnvironmentLayoutOptionsForwarding
ASEnvironmentLayoutExtensibilityForwarding

- (ASTraitCollection *)asyncTraitCollection
{
  ASDN::MutexLocker l(_propertyLock);
  return [ASTraitCollection traitCollectionWithASEnvironmentTraitCollection:_environmentState.traitCollection];
}

@end

@implementation ASLayoutSpec (Debugging)

#pragma mark - ASLayoutProducerAsciiArtProtocol

+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName direction:(ASStackLayoutDirection)direction
{
  NSMutableArray *childStrings = [NSMutableArray array];
  for (id<ASLayoutProducerAsciiArtProtocol> layoutChild in children) {
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

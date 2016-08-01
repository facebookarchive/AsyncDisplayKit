//
//  ASLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutSpec+Private.h"

#import "ASAssert.h"
#import "ASEnvironmentInternal.h"

#import "ASLayout.h"
#import "ASThread.h"
#import "ASTraitCollection.h"

#import <vector>

@interface ASLayoutSpec() {
  ASEnvironmentState _environmentState;
  ASDN::RecursiveMutex __instanceLock__;
  ASChildrenMap _childrenMap;
  unsigned long _mutations;
}
@end

@implementation ASLayoutSpec

// these dynamic properties all defined in ASLayoutOptionsPrivate.m
@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis,
         alignSelf, ascender, descender, sizeRange, layoutPosition, layoutableType;
@synthesize parent = _parent;
@synthesize isFinalLayoutable = _isFinalLayoutable;

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  _isMutable = YES;
  _environmentState = ASEnvironmentStateMakeDefault();
  _mutations = 0;
  return self;
}

- (ASLayoutableType)layoutableType
{
  return ASLayoutableTypeLayoutSpec;
}

- (BOOL)canLayoutAsynchronous
{
  return YES;
}

#pragma mark - Layout

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutableObject:self
                         constrainedSizeRange:constrainedSize
                                         size:constrainedSize.min];
}

- (id<ASLayoutable>)finalLayoutable
{
  return self;
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

#pragma mark - Parent

- (void)setParent:(id<ASLayoutable>)parent
{
  // FIXME: Locking should be evaluated here.  _parent is not widely used yet, though.
  _parent = parent;
  
  if ([parent supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(parent, self.environmentState.layoutOptionsState);
  }
}

- (id<ASLayoutable>)parent
{
  return _parent;
}

#pragma mark - Children

- (void)setChild:(id<ASLayoutable>)child
{
  [self setChild:child forIndex:0];
}

- (void)setChild:(id<ASLayoutable>)child forIndex:(NSUInteger)index
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (child) {
    id<ASLayoutable> finalLayoutable = [self layoutableToAddFromLayoutable:child];
    if (finalLayoutable) {
      _childrenMap[index] = finalLayoutable;
      [self propagateUpLayoutable:finalLayoutable];
    }
  } else {
    _childrenMap.erase(index);
  }
  _mutations++;
  
  // TODO: Should we propagate up the layoutable as it could happen that multiple children will propagated up their
  //       layout options and one child will overwrite values from another child
  // [self propagateUpLayoutable:finalLayoutable];
}

- (void)setChildren:(NSArray<id<ASLayoutable>> *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  _childrenMap.clear();
  NSUInteger i = 0;
  for (id<ASLayoutable> child in children) {
    _childrenMap[i] = [self layoutableToAddFromLayoutable:child];
    i += 1;
    
    _mutations++;
  }
}

- (id<ASLayoutable>)childForIndex:(NSUInteger)index
{
  if (index < _childrenMap.size()) {
    return _childrenMap[index];
  }
  return nil;
}

- (id<ASLayoutable>)child
{
  return _childrenMap[0];
}

- (NSArray *)children
{
  // If used inside ASDK, the childrenMap property should be preferred over the children array to prevent
  // unecessary boxing
  std::vector<ASLayout *> children;
  for (auto const &entry : _childrenMap) {
    children.push_back(entry.second);
  }

  return [NSArray arrayWithObjects:&children[0] count:children.size()];
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])stackbuf
                                    count:(NSUInteger)stackbufLength
{
  NSUInteger count = 0;
  unsigned long countOfItemsAlreadyEnumerated = state->state;
  
  if (countOfItemsAlreadyEnumerated == 0) {
    state->mutationsPtr = &_mutations;
  }

  if (countOfItemsAlreadyEnumerated < _childrenMap.size()) {
    state->itemsPtr = stackbuf;
        
    while((countOfItemsAlreadyEnumerated < _childrenMap.size()) && (count < stackbufLength)) {
      // Hold on for the object while enumerating
      __autoreleasing id child = _childrenMap[countOfItemsAlreadyEnumerated];
      stackbuf[count] = child;
      countOfItemsAlreadyEnumerated++;
      count++;
    }
  } else {
    count = 0;
  }
  
  state->state = countOfItemsAlreadyEnumerated;

  return count;
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

- (void)propagateUpLayoutable:(id<ASLayoutable>)layoutable
{
  if ([layoutable isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)layoutable setParent:self]; // This will trigger upward propogation if needed.
  } else if ([self supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(self, layoutable.environmentState.layoutOptionsState); // Probably an ASDisplayNode
  }
}

- (ASEnvironmentTraitCollection)environmentTraitCollection
{
  return _environmentState.environmentTraitCollection;
}

- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  _environmentState.environmentTraitCollection = environmentTraitCollection;
}

ASEnvironmentLayoutOptionsForwarding
ASEnvironmentLayoutExtensibilityForwarding

- (ASTraitCollection *)asyncTraitCollection
{
  ASDN::MutexLocker l(__instanceLock__);
  return [ASTraitCollection traitCollectionWithASEnvironmentTraitCollection:self.environmentTraitCollection];
}

@end

@implementation ASLayoutSpec (Private)

- (ASChildrenMap)childrenMap
{
  return _childrenMap;
}

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

//
//  ASLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutSpec.h"

#import "ASAssert.h"
#import "ASInternalHelpers.h"
#import "ASEnvironmentInternal.h"

#import "ASLayout.h"
#import "ASThread.h"
#import "ASTraitCollection.h"

#import <objc/runtime.h>
#import <map>
#import <vector>

typedef std::map<unsigned long, id<ASLayoutable>, std::less<unsigned long>> ASChildMap;

@interface ASLayoutSpec() {
  ASDN::RecursiveMutex __instanceLock__;
  ASLayoutableSize _size;
  ASEnvironmentState _environmentState;
  ASChildMap _children;
}
@end

@implementation ASLayoutSpec

// Dynamic properties for ASLayoutables
@dynamic layoutableType, size;
// Dynamic properties for sizing
@dynamic width, height, minWidth, maxWidth, minHeight, maxHeight;
// Dynamic properties for stack spec
@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis, alignSelf, ascender, descender;
// Dynamic properties for static spec
@dynamic layoutPosition;

@synthesize isFinalLayoutable = _isFinalLayoutable;

#pragma mark - Class

+ (void)initialize
{
  [super initialize];
  if (self != [ASLayoutSpec class]) {
    ASDisplayNodeAssert(!ASSubclassOverridesSelector([ASLayoutSpec class], self, @selector(measureWithSizeRange:)), @"Subclass %@ must not override measureWithSizeRange: method. Instead overwrite calculateLayoutThatFits:", NSStringFromClass(self));
  }
}


#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  _isMutable = YES;
  _size = ASLayoutableSizeMake();
  _environmentState = ASEnvironmentStateMakeDefault();
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


#pragma mark - Sizing

- (ASLayoutableSize)size
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size;
}

- (void)setSize:(ASLayoutableSize)size
{
  ASDN::MutexLocker l(__instanceLock__);
  _size = size;
}

ASLayoutableSizeForwarding
ASLayoutableSizeHelperForwarding


#pragma mark - Layout

// Deprecated
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
    return [self layoutThatFits:constrainedSize];
}

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];
}

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize
{
  return [self calculateLayoutThatFits:constrainedSize restrictedToSize:_size relativeToParentSize:parentSize];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutableSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutableSizeResolve(_size, parentSize));
  return [self calculateLayoutThatFits:resolvedRange];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutable:self size:constrainedSize.min];
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

- (void)setParent:(id<ASLayoutable>)parent
{
  // FIXME: Locking should be evaluated here.  _parent is not widely used yet, though.
  _parent = parent;
  
  if ([parent supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(parent, self.environmentState.layoutOptionsState);
  }
}

- (void)setChild:(id<ASLayoutable>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (child) {
    id<ASLayoutable> finalLayoutable = [self layoutableToAddFromLayoutable:child];
    if (finalLayoutable) {
      _children[0] = finalLayoutable;
      [self propagateUpLayoutable:finalLayoutable];
    }
  } else {
    _children.erase(0);
  }
}

- (void)setChild:(id<ASLayoutable>)child forIndex:(NSUInteger)index
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (child) {
    id<ASLayoutable> finalLayoutable = [self layoutableToAddFromLayoutable:child];
    _children[index] = finalLayoutable;
  } else {
    _children.erase(index);
  }
  // TODO: Should we propagate up the layoutable at it could happen that multiple children will propagated up their
  //       layout options and one child will overwrite values from another child
  // [self propagateUpLayoutable:finalLayoutable];
}

- (void)setChildren:(NSArray<id<ASLayoutable>> *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  _children.clear();
  NSUInteger i = 0;
  for (id<ASLayoutable> child in children) {
    _children[i] = [self layoutableToAddFromLayoutable:child];
    i += 1;
  }
}

- (id<ASLayoutable>)childForIndex:(NSUInteger)index
{
  if (index < _children.size()) {
    return _children[index];
  }
  return nil;
}

- (id<ASLayoutable>)child
{
  return _children[0];
}

- (NSArray *)children
{
  std::vector<ASLayout *> children;
  for (ASChildMap::iterator it = _children.begin(); it != _children.end(); ++it ) {
    children.push_back(it->second);
  }
  
  return [NSArray arrayWithObjects:&children[0] count:children.size()];
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


#pragma mark - ASWrapperLayoutSpec

@implementation ASWrapperLayoutSpec

+ (instancetype)wrapperWithLayoutable:(id<ASLayoutable>)layoutable
{
  return [[self alloc] initWithLayoutable:layoutable];
}

- (instancetype)initWithLayoutable:(id<ASLayoutable>)layoutable
{
  self = [super init];
  if (self) {
    self.child = layoutable;
  }
  return self;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  ASLayout *sublayout = [self.child layoutThatFits:constrainedSize parentSize:constrainedSize.max];
  sublayout.position = CGPointZero;
  return [ASLayout layoutWithLayoutable:self size:sublayout.size sublayouts:@[sublayout]];
}

@end


#pragma mark - ASLayoutSpec (Debugging)

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

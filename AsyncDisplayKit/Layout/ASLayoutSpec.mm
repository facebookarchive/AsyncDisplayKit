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
#import "ASLayoutSpecPrivate.h"
#import "ASLayoutSpec+Subclasses.h"

@implementation ASLayoutSpec

// Dynamic properties for ASLayoutables
@dynamic layoutableType;
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
  _environmentState = ASEnvironmentStateMakeDefault();
  _style = [[ASLayoutableStyle alloc] init];
  _childrenArray = [NSPointerArray strongObjectsPointerArray];
  
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

#pragma mark - Final Layoutable

- (id<ASLayoutable>)finalLayoutable
{
  return self;
}

#pragma mark - Style

- (ASLayoutableStyle *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}

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
  return [self calculateLayoutThatFits:constrainedSize restrictedToSize:_style.size relativeToParentSize:parentSize];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutableSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutableSizeResolve(_style.size, parentSize));
  return [self calculateLayoutThatFits:resolvedRange];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutable:self size:constrainedSize.min];
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


#pragma mark - Child

- (void)setChild:(id<ASLayoutable>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASDisplayNodeAssert(_childrenArray.count < 2, @"This layout spec does not support more than one child. Use the setChildren: or the setChild:AtIndex: API");
  
  if (child) {
    id<ASLayoutable> finalLayoutable = [self layoutableToAddFromLayoutable:child];
    if (finalLayoutable) {
      [_childrenArray insertPointer:(__bridge void *)finalLayoutable atIndex:0];
      [self propagateUpLayoutable:finalLayoutable];
    }
  } else {
    if (_childrenArray.count) {
      [_childrenArray removePointerAtIndex:0];
    }
  }
}

- (id<ASLayoutable>)child
{
  ASDisplayNodeAssert(_childrenArray.count < 2, @"This layout spec does not support more than one child. Use the setChildren: or the setChild:AtIndex: API");
  return(__bridge id<ASLayoutable>) [_childrenArray pointerAtIndex:0];
}

#pragma mark - Children

- (void)setChildren:(NSArray<id<ASLayoutable>> *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");

  NSUInteger count = _childrenArray.count;
  for (NSUInteger i = 0; i < count; i++) {
    [_childrenArray removePointerAtIndex:i];
  }
    
  for (id<ASLayoutable> child in children) {
    [_childrenArray addPointer:(__bridge void *)[self layoutableToAddFromLayoutable:child]];
  }
}

- (NSArray *)children
{
  return [_childrenArray copy];
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nullable [_Nonnull])buffer count:(NSUInteger)len
{
  return [_childrenArray countByEnumeratingWithState:state objects:buffer count:len];
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

- (ASTraitCollection *)asyncTraitCollection
{
  ASDN::MutexLocker l(__instanceLock__);
  return [ASTraitCollection traitCollectionWithASEnvironmentTraitCollection:self.environmentTraitCollection];
}

ASEnvironmentLayoutExtensibilityForwarding

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

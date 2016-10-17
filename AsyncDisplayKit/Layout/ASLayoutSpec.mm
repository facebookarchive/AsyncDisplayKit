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

#import "ASLayoutElementStylePrivate.h"

@implementation ASLayoutSpec

// Dynamic properties for ASLayoutElements
@dynamic layoutElementType;
@synthesize isFinalLayoutElement = _isFinalLayoutElement;

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
  _childrenArray = [[NSMutableArray alloc] init];
  
  return self;
}

- (ASLayoutElementType)layoutElementType
{
  return ASLayoutElementTypeLayoutSpec;
}

- (BOOL)canLayoutAsynchronous
{
  return YES;
}

#pragma mark - Final LayoutElement

- (id<ASLayoutElement>)finalLayoutElement
{
  return self;
}

#pragma mark - Style

- (ASLayoutElementStyle *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_style == nil) {
    _style = [[ASLayoutElementStyle alloc] init];
  }
  return _style;
}

- (instancetype)styledWithBlock:(void (^)(ASLayoutElementStyle *style))styleBlock
{
  styleBlock(self.style);
  return self;
}

#pragma mark - Layout

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];
}

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize
{
  return [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutElementSizeResolve(self.style.size, parentSize));
  return [self calculateLayoutThatFits:resolvedRange];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutElement:self size:constrainedSize.min];
}


#pragma mark - Parent

- (void)setParent:(id<ASLayoutElement>)parent
{
  // FIXME: Locking should be evaluated here.  _parent is not widely used yet, though.
  _parent = parent;
  
  if ([parent supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(parent, self.environmentState.layoutOptionsState);
  }
}

#pragma mark - Child

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");;
  ASDisplayNodeAssert(_childrenArray.count < 2, @"This layout spec does not support more than one child. Use the setChildren: or the setChild:AtIndex: API");
  
  if (child) {
    id<ASLayoutElement> finalLayoutElement = [self layoutElementToAddFromLayoutElement:child];
    if (finalLayoutElement) {
      _childrenArray[0] = finalLayoutElement;
      [self propagateUpLayoutElement:finalLayoutElement];
    }
  } else {
    if (_childrenArray.count) {
      [_childrenArray removeObjectAtIndex:0];
    }
  }
}

- (id<ASLayoutElement>)child
{
  ASDisplayNodeAssert(_childrenArray.count < 2, @"This layout spec does not support more than one child. Use the setChildren: or the setChild:AtIndex: API");
  
  if (_childrenArray.count) {
    return _childrenArray[0];
  }
  
  return nil;
}

#pragma mark - Children

- (void)setChildren:(NSArray<id<ASLayoutElement>> *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  [_childrenArray removeAllObjects];
  
  NSUInteger i = 0;
  for (id<ASLayoutElement> child in children) {
    ASDisplayNodeAssert([child conformsToProtocol:NSProtocolFromString(@"ASLayoutElement")], @"Child %@ of spec %@ is not an ASLayoutElement!", child, self);
    _childrenArray[i] = [self layoutElementToAddFromLayoutElement:child];
    i += 1;
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
// specification has more than one child. Currently ASStackLayoutSpec and ASAbsoluteLayoutSpec are currently
// the specifications that are known to have more than one.
- (BOOL)supportsUpwardPropagation
{
  return ASEnvironmentStatePropagationEnabled();
}

- (BOOL)supportsTraitsCollectionPropagation
{
  return ASEnvironmentStateTraitCollectionPropagationEnabled();
}

- (void)propagateUpLayoutElement:(id<ASLayoutElement>)layoutElement
{
  if ([layoutElement isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)layoutElement setParent:self]; // This will trigger upward propogation if needed.
  } else if ([self supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(self, layoutElement.environmentState.layoutOptionsState); // Probably an ASDisplayNode
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

#pragma mark - Deprecated

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize];
}


ASLayoutElementStyleForwarding

@end

#pragma mark - ASWrapperLayoutSpec

@implementation ASWrapperLayoutSpec

+ (instancetype)wrapperWithLayoutElement:(id<ASLayoutElement>)layoutElement
{
  return [[self alloc] initWithLayoutElement:layoutElement];
}

- (instancetype)initWithLayoutElement:(id<ASLayoutElement>)layoutElement
{
  self = [super init];
  if (self) {
    self.child = layoutElement;
  }
  return self;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  ASLayout *sublayout = [self.child layoutThatFits:constrainedSize parentSize:constrainedSize.max];
  sublayout.position = CGPointZero;
  return [ASLayout layoutWithLayoutElement:self size:sublayout.size sublayouts:@[sublayout]];
}

@end


#pragma mark - ASLayoutSpec (Debugging)

@implementation ASLayoutSpec (Debugging)

#pragma mark - ASLayoutElementAsciiArtProtocol

+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName direction:(ASStackLayoutDirection)direction
{
  NSMutableArray *childStrings = [NSMutableArray array];
  for (id<ASLayoutElementAsciiArtProtocol> layoutChild in children) {
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

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

typedef std::map<unsigned long, id<ASLayoutElement>, std::less<unsigned long>> ASChildMap;

@interface ASLayoutSpec() {
  ASDN::RecursiveMutex __instanceLock__;
  ASChildMap _children;
  ASEnvironmentState _environmentState;
  ASLayoutElementStyle *_style;
}
@end

@implementation ASLayoutSpec

// Dynamic properties for ASLayoutElements
@dynamic layoutElementType, style;
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
  _style = [[ASLayoutElementStyle alloc] init];
  
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

- (ASLayoutElementStyle *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}

#pragma mark - Style

+ (Class)styleClass
{
  return [ASLayoutElementStyle class];
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
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutElementSizeResolve(_style.size, parentSize));
  return [self calculateLayoutThatFits:resolvedRange];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout layoutWithLayoutElement:self size:constrainedSize.min];
}

- (id<ASLayoutElement>)finalLayoutElement
{
  return self;
}

- (id<ASLayoutElement>)layoutElementToAddFromLayoutElement:(id<ASLayoutElement>)child
{
  if (self.isFinalLayoutElement == NO) {
    
    // If you are getting recursion crashes here after implementing finalLayoutElement, make sure
    // that you are setting isFinalLayoutElement flag to YES. This must be one BEFORE adding a child
    // to the new ASLayoutElement.
    //
    // For example:
    //- (id<ASLayoutElement>)finalLayoutElement
    //{
    //  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
    //  insetSpec.insets = UIEdgeInsetsMake(10,10,10,10);
    //  insetSpec.isFinalLayoutElement = YES;
    //  [insetSpec setChild:self];
    //  return insetSpec;
    //}

    id<ASLayoutElement> finalLayoutElement = [child finalLayoutElement];
    if (finalLayoutElement != child) {
      if (ASEnvironmentStatePropagationEnabled()) {
        ASEnvironmentStatePropagateUp(finalLayoutElement, child.environmentState.layoutOptionsState);
      } else {
        // If state propagation is not enabled the layout options state needs to be copied manually
        ASEnvironmentState finalLayoutElementEnvironmentState = finalLayoutElement.environmentState;
        finalLayoutElementEnvironmentState.layoutOptionsState = child.environmentState.layoutOptionsState;
        finalLayoutElement.environmentState = finalLayoutElementEnvironmentState;
      }
      return finalLayoutElement;
    }
  }
  return child;
}

- (void)setParent:(id<ASLayoutElement>)parent
{
  // FIXME: Locking should be evaluated here.  _parent is not widely used yet, though.
  _parent = parent;
  
  if ([parent supportsUpwardPropagation]) {
    ASEnvironmentStatePropagateUp(parent, self.environmentState.layoutOptionsState);
  }
}

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (child) {
    id<ASLayoutElement> finalLayoutElement = [self layoutElementToAddFromLayoutElement:child];
    if (finalLayoutElement) {
      _children[0] = finalLayoutElement;
      [self propagateUpLayoutElement:finalLayoutElement];
    }
  } else {
    _children.erase(0);
  }
}

- (void)setChild:(id<ASLayoutElement>)child forIndex:(NSUInteger)index
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (child) {
    id<ASLayoutElement> finalLayoutElement = [self layoutElementToAddFromLayoutElement:child];
    _children[index] = finalLayoutElement;
  } else {
    _children.erase(index);
  }
  // TODO: Should we propagate up the layoutElement at it could happen that multiple children will propagated up their
  //       layout options and one child will overwrite values from another child
  // [self propagateUpLayoutElement:finalLayoutElement];
}

- (void)setChildren:(NSArray<id<ASLayoutElement>> *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  
  _children.clear();
  NSUInteger i = 0;
  for (id<ASLayoutElement> child in children) {
    _children[i] = [self layoutElementToAddFromLayoutElement:child];
    i += 1;
  }
}

- (id<ASLayoutElement>)childForIndex:(NSUInteger)index
{
  if (index < _children.size()) {
    return _children[index];
  }
  return nil;
}

- (id<ASLayoutElement>)child
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

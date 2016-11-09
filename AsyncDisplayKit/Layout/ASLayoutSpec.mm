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
#import "ASLayoutSpec+Debug.h"

#import <objc/runtime.h>
#import <map>
#import <vector>

@implementation ASLayoutSpec

// Dynamic properties for ASLayoutElements
@dynamic layoutElementType;
@synthesize debugName = _debugName;
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
  if (ASLayoutElementGetCurrentContext().needsVisualizeNode && !self.neverShouldVisualize) {
    return [[ASLayoutSpecVisualizerNode alloc] initWithLayoutSpec:self];
  } else {
    return self;
  }
}

- (void)recursivelySetShouldVisualize:(BOOL)visualize
{
  NSMutableArray *mutableChildren = [self.children mutableCopy];
  
  for (id<ASLayoutElement>layoutElement in self.children) {
    if (layoutElement.layoutElementType == ASLayoutElementTypeLayoutSpec) {
      ASLayoutSpec *layoutSpec = (ASLayoutSpec *)layoutElement;
      
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

#pragma mark - Child

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASDisplayNodeAssert(_childrenArray.count < 2, @"This layout spec does not support more than one child. Use the setChildren: or the setChild:AtIndex: API");
 
  if (child) {
    if (child.layoutElementType == ASLayoutElementTypeLayoutSpec) {
      [(ASLayoutSpec *)child setShouldVisualize:self.shouldVisualize];
    }
    id<ASLayoutElement> finalLayoutElement = [self layoutElementToAddFromLayoutElement:child];
    if (finalLayoutElement) {
      _childrenArray[0] = finalLayoutElement;
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
  
  return _childrenArray.firstObject;
}

#pragma mark - Children

- (void)setChildren:(NSArray<id<ASLayoutElement>> *)children
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");

  [_childrenArray removeAllObjects];
  
  NSUInteger i = 0;
  for (id<ASLayoutElement> child in children) {
    ASDisplayNodeAssert([child conformsToProtocol:NSProtocolFromString(@"ASLayoutElement")], @"Child %@ of spec %@ is not an ASLayoutElement!", child, self);
    id <ASLayoutElement> finalLayoutElement = [self layoutElementToAddFromLayoutElement:child];
    if (finalLayoutElement.layoutElementType == ASLayoutElementTypeLayoutSpec) {
      [(ASLayoutSpec *)finalLayoutElement setShouldVisualize:self.shouldVisualize];
    }
    _childrenArray[i] = finalLayoutElement;
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

- (BOOL)supportsTraitsCollectionPropagation
{
  return ASEnvironmentStateTraitCollectionPropagationEnabled();
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

#pragma mark - Framework Private

- (nullable NSSet<id<ASLayoutElement>> *)findDuplicatedElementsInSubtree
{
  NSMutableSet *result = nil;
  NSUInteger count = 0;
  [self _findDuplicatedElementsInSubtreeWithWorkingSet:[[NSMutableSet alloc] init] workingCount:&count result:&result];
  return result;
}

/**
 * This method is extremely performance-sensitive, so we do some strange things.
 *
 * @param workingSet A working set of elements for use in the recursion.
 * @param workingCount The current count of the set for use in the recursion.
 * @param result The set into which to put the result. This initially points to @c nil to save time if no duplicates exist.
 */
- (void)_findDuplicatedElementsInSubtreeWithWorkingSet:(NSMutableSet<id<ASLayoutElement>> *)workingSet workingCount:(NSUInteger *)workingCount result:(NSMutableSet<id<ASLayoutElement>>  * _Nullable *)result
{
  Class layoutSpecClass = [ASLayoutSpec class];

  for (id<ASLayoutElement> child in self) {
    // Add the object into the set.
    [workingSet addObject:child];

    // Check that addObject: caused the count to increase.
    // This is faster than using containsObject.
    NSUInteger oldCount = *workingCount;
    NSUInteger newCount = workingSet.count;
    BOOL objectAlreadyExisted = (newCount != oldCount + 1);
    if (objectAlreadyExisted) {
      if (*result == nil) {
        *result = [[NSMutableSet alloc] init];
      }
      [*result addObject:child];
    } else {
      *workingCount = newCount;
      // If child is a layout spec we haven't visited, recurse its children.
      if ([child isKindOfClass:layoutSpecClass]) {
        [(ASLayoutSpec *)child _findDuplicatedElementsInSubtreeWithWorkingSet:workingSet workingCount:workingCount result:result];
      }
    }
  }
}

#pragma mark - Debugging

- (NSString *)debugName
{
  ASDN::MutexLocker l(__instanceLock__);
  return _debugName;
}

- (void)setDebugName:(NSString *)debugName
{
  ASDN::MutexLocker l(__instanceLock__);
  if (!ASObjectIsEqual(_debugName, debugName)) {
    _debugName = [debugName copy];
  }
}

#pragma mark - Deprecated

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize];
}

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

+ (instancetype)wrapperWithLayoutElements:(NSArray<id<ASLayoutElement>> *)layoutElements
{
  return [[self alloc] initWithLayoutElements:layoutElements];
}

- (instancetype)initWithLayoutElements:(NSArray<id<ASLayoutElement>> *)layoutElements
{
  self = [super init];
  if (self) {
    self.children = layoutElements;
  }
  return self;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  NSArray *children = self.children;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:children.count];
  
  CGSize size = constrainedSize.min;
  for (id<ASLayoutElement> child in children) {
    ASLayout *sublayout = [child layoutThatFits:constrainedSize parentSize:constrainedSize.max];
    sublayout.position = CGPointZero;
    
    size.width = MAX(size.width,  sublayout.size.width);
    size.height = MAX(size.height, sublayout.size.height);
    
    [sublayouts addObject:sublayout];
  }
  
  return [ASLayout layoutWithLayoutElement:self size:size sublayouts:sublayouts];
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
  NSArray *children = self.children.count < 2 && self.child ? @[self.child] : self.children;
  return [ASLayoutSpec asciiArtStringForChildren:children parentName:[self asciiArtName]];
}

- (NSString *)asciiArtName
{
  NSString *string = NSStringFromClass([self class]);
  if (_debugName) {
    string = [string stringByAppendingString:[NSString stringWithFormat:@" (debugName = %@)",_debugName]];
  }
  return string;
}

@end

#pragma mark - ASLayoutSpec (Deprecated)

@implementation ASLayoutSpec (Deprecated)

ASLayoutElementStyleForwarding

@end

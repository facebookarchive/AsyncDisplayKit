//
//  ASLayoutSpecDebuggingContext.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASLayoutSpecDebuggingContext.h"
#import "ASAssert.h"
#import "ASObjectDescriptionHelpers.h"

@interface ASLayoutSpecDebuggingContext ()
@property (nonatomic, strong) id<ASLayoutElement> element;
@end

@implementation ASLayoutSpecDebuggingContext

+ (ASLayoutSpecDebuggingContext *)contextWithElementIdentifier:(id)identifier
{
  /**
   * Note: Currently this just grows and grows. In practice it's not a big problem
   * because these don't take up much memory and
   */
  static NSMapTable<NSNumber *, ASLayoutSpecDebuggingContext *> *storage;
  static NSLock *contextsLock;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    storage = [NSMapTable strongToStrongObjectsMapTable];
    contextsLock = [[NSLock alloc] init];
  });
  [contextsLock lock];
  ASLayoutSpecDebuggingContext *context = [storage objectForKey:identifier];
  if (context == nil) {
    context = [[ASLayoutSpecDebuggingContext alloc] initWithIdentifier:identifier];
    [storage setObject:context forKey:identifier];
  }
  [contextsLock unlock];
  
  return context;
}

- (instancetype)initWithIdentifier:(id)identifier
{
  if (self = [super init]) {
    _overriddenProperties = @{};
  }
  return self;
}

- (void)setOverriddenProperties:(NSDictionary<NSString *,id> *)overriddenProperties
{
  _overriddenProperties = overriddenProperties;
  [self _applyPropertyOverrides];
}

- (void)setElement:(id<ASLayoutElement>)element
{
  if (element != _element) {
    _element = element;
    [self _captureDefaultProperties];
    [self _applyPropertyOverrides];
  }
}

- (void)_captureDefaultProperties
{
  NSMutableDictionary *newDefaultProps = [NSMutableDictionary dictionary];
  for (NSString *keyPath in self.overriddenProperties) {
    newDefaultProps[keyPath] = [(id)_element valueForKeyPath:keyPath];
  }
  _defaultProperties = newDefaultProps;
}

- (void)_applyPropertyOverrides
{
  // Cast is ugly but we enforce id<NSObject> which is pretty dern close and this is internal.
  [(NSObject *)self.element setValuesForKeysWithDictionary:self.overriddenProperties];
}


@end

static NSString *const ASLayoutDebugTreeRootKey = @"org.asyncdisplaykit.rootLayoutSpecTree";
static NSString *const ASLayoutDebugTreeCurrentKey = @"org.asyncdisplaykit.currentLayoutSpecTree";

@interface ASLayoutSpecTree ()
@property (nonatomic, weak) ASLayoutSpecTree *parent;
@end

@implementation ASLayoutSpecTree {
  NSMutableArray<ASLayoutSpecTree *> *_subtrees;
}

+ (void)beginWithElement:(id<ASLayoutElement>)element
{
  ASLayoutSpecTree *current = [self currentTree];
  ASLayoutSpecTree *tree = [[ASLayoutSpecTree alloc] initWithElement:element];
  NSMutableDictionary *dict = [NSThread currentThread].threadDictionary;
  if (current == nil) {
    dict[ASLayoutDebugTreeRootKey] = tree;
  } else {
    [current addSubtree:tree];
  }
  dict[ASLayoutDebugTreeCurrentKey] = tree;
}

+ (ASLayoutSpecTree *)rootTree
{
  return [NSThread currentThread].threadDictionary[ASLayoutDebugTreeRootKey];
}

+ (ASLayoutSpecTree *)currentTree
{
  return [NSThread currentThread].threadDictionary[ASLayoutDebugTreeCurrentKey];
}

+ (void)end
{
  ASLayoutSpecTree *currentTree = [self currentTree];
  ASLayoutSpecTree *parent = currentTree.parent;
  NSMutableDictionary *dict = [NSThread currentThread].threadDictionary;
  dict[ASLayoutDebugTreeCurrentKey] = parent;
  if (parent == nil) {
    dict[ASLayoutDebugTreeRootKey] = nil;
  }
}

- (instancetype)initWithElement:(id<ASLayoutElement>)element
{
  if (self = [super init]) {
    _subtrees = [NSMutableArray array];
    _context = [ASLayoutSpecDebuggingContext contextWithElementIdentifier:element.identifier];
    _context.element = element;
  }
  return self;
}

- (void)addSubtree:(ASLayoutSpecTree *)tree
{
  [_subtrees addObject:tree];
  tree.parent = self;
}

- (ASLayoutSpecTree *)subtreeForElement:(id<ASLayoutElement>)element
{
  if ([element.identifier isEqual:self.context.element.identifier]) {
    return self;
  } else {
    for (ASLayoutSpecTree *sub in self.subtrees) {
      ASLayoutSpecTree *result = [sub subtreeForElement:element];
      if (result != nil) {
        return result;
      }
    }
  }
  return nil;
}

- (NSInteger)totalCount
{
  NSInteger result = 1;
  for (ASLayoutSpecTree *tree in self.subtrees) {
    result += tree.totalCount;
  }
  return result;
}

- (NSIndexPath *)indexPathForIndex:(NSInteger)index
{
  NSInteger idx = 0;
  return [self _indexPathForIndex:index runningIndex:&idx baseIndexPath:[NSIndexPath new]];
}

- (NSIndexPath *)_indexPathForIndex:(NSInteger)index runningIndex:(NSInteger *)runningIndex baseIndexPath:(NSIndexPath *)baseIndexPath
{
  if (index == *runningIndex) {
    return baseIndexPath;
  }
  
  NSInteger i = 0;
  for (ASLayoutSpecTree *s in self.subtrees) {
    *runningIndex += 1;
    NSIndexPath *newBase = [baseIndexPath indexPathByAddingIndex:i++];
    NSIndexPath *result = [s _indexPathForIndex:index runningIndex:runningIndex baseIndexPath:newBase];
    if (result) {
      return result;
    }
  }
  return nil;
}

- (ASLayoutSpecTree *)subtreeAtIndexPath:(NSIndexPath *)indexPath
{
  NSInteger l = indexPath.length;
  ASLayoutSpecTree *t = self;
  for (NSInteger p = 0; p < l; p++) {
    NSInteger i = [indexPath indexAtPosition:p];
    t = t.subtrees[i];
  }
  return t;
}

#pragma mark - Description

- (NSString *)description
{
  NSMutableString *result = [NSMutableString string];
  [self _descriptionHelperWithIndentation:[NSMutableString string] result:result];
  return result;
}

- (void)_descriptionHelperWithIndentation:(NSMutableString *)indentation result:(NSMutableString *)mutableString
{
  NSInteger indentationLength = indentation.length;
  [mutableString appendFormat:@"%@TreeForElement: %@ %@\n", indentation, ASObjectDescriptionMakeTiny(self.context.element), self.context.element.identifier];
  for (ASLayoutSpecTree *element in self.subtrees) {
    [indentation appendString:@"\t"];
    [element _descriptionHelperWithIndentation:indentation result:mutableString];
    [indentation deleteCharactersInRange:NSMakeRange(indentationLength, 1)];
  }
}


@end

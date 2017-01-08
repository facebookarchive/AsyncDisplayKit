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

+ (ASLayoutSpecDebuggingContext *)contextWithElement:(id<ASLayoutElement>)element
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
  id identifier = element.identifier;
  [contextsLock lock];
  ASLayoutSpecDebuggingContext *context = [storage objectForKey:identifier];
  if (context == nil) {
    context = [[ASLayoutSpecDebuggingContext alloc] initWithIdentifier:identifier];
    context.element = element;
    [storage setObject:context forKey:identifier];
  } else {
    context.element = element;
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
  _element = element;
  [self _applyPropertyOverrides];
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
    _context = [ASLayoutSpecDebuggingContext contextWithElement:element];
  }
  return self;
}

- (void)addSubtree:(ASLayoutSpecTree *)tree
{
  [_subtrees addObject:tree];
  tree.parent = self;
}

- (ASLayoutSpecTree *)subtreeAtIndexPath:(NSIndexPath *)indexPath
{
  NSInteger l = indexPath.length;
  ASLayoutSpecTree *tree = self;
  for (NSInteger p = 0; p < l; p++) {
    NSInteger i = [indexPath indexAtPosition:p];
    tree = tree.subtrees[i];
  }
  return tree;
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

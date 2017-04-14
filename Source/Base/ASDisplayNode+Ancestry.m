//
//  ASNodeAncestorEnumerator.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDisplayNode+Ancestry.h"

AS_SUBCLASSING_RESTRICTED
@interface ASNodeAncestryEnumerator : NSEnumerator
@end

@implementation ASNodeAncestryEnumerator {
  /// Would be nice to use __unsafe_unretained but nodes can be
  /// deallocated on arbitrary threads so nope.
  __weak ASDisplayNode * _nextNode;
}

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (self = [super init]) {
    _nextNode = node;
  }
  return self;
}

- (id)nextObject
{
  ASDisplayNode *node = _nextNode;
  _nextNode = [node supernode];
  return node;
}

@end

@implementation ASDisplayNode (Ancestry)

- (NSEnumerator *)ancestorEnumeratorWithSelf:(BOOL)includeSelf
{
  ASDisplayNode *node = includeSelf ? self : self.supernode;
  return [[ASNodeAncestryEnumerator alloc] initWithNode:node];
}

- (NSString *)ancestryDescription
{
  NSMutableArray *strings = [NSMutableArray array];
  for (ASDisplayNode *node in [self ancestorEnumeratorWithSelf:YES]) {
    [strings addObject:ASObjectDescriptionMakeTiny(node)];
  }
  return strings.description;
}

@end

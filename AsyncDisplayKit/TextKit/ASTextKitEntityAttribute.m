//
//  ASTextKitEntityAttribute.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitEntityAttribute.h"

@implementation ASTextKitEntityAttribute

- (instancetype)initWithEntity:(id<NSObject>)entity
{
  if (self = [super init]) {
    _entity = entity;
  }
  return self;
}

- (NSUInteger)hash
{
  return [_entity hash];
}

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[self class]]) {
    return NO;
  }
  ASTextKitEntityAttribute *other = (ASTextKitEntityAttribute *)object;
  return _entity == other.entity || [_entity isEqual:other.entity];
}

@end

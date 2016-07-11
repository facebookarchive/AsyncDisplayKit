//
//  ASTextKitEntityAttribute.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

/**
 The object that should be embedded with ASTextKitEntityAttributeName.  Please note that the entity you provide MUST
 implement a proper hash and isEqual function or your application performance will grind to a halt due to
 NSMutableAttributedString's usage of a global hash table of all attributes.  This means the entity should NOT be a
 Foundation Collection (NSArray, NSDictionary, NSSet, etc.) since their hash function is a simple count of the values
 in the collection, which causes pathological performance problems deep inside NSAttributedString's implementation.

 rdar://19352367
 */
@interface ASTextKitEntityAttribute : NSObject

@property (nonatomic, strong, readonly) id<NSObject> entity;

- (instancetype)initWithEntity:(id<NSObject>)entity;

@end

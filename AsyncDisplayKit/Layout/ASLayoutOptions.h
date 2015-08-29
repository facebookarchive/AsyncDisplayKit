/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <Foundation/Foundation.h>

@protocol ASLayoutable;

#import <AsyncDisplayKit/ASBaselineLayoutable.h>
#import <AsyncDisplayKit/ASStackLayoutable.h>
#import <AsyncDisplayKit/ASStaticLayoutable.h>

@interface ASLayoutOptions : NSObject <ASBaselineLayoutable, ASStackLayoutable, ASStaticLayoutable, NSCopying>

+ (void)setDefaultLayoutOptionsClass:(Class)defaultLayoutOptionsClass;
+ (Class)defaultLayoutOptionsClass;

- (instancetype)initWithLayoutable:(id<ASLayoutable>)layoutable;
- (void)setValuesFromLayoutable:(id<ASLayoutable>)layoutable;

#pragma mark - Subclasses should implement these!
+ (NSSet *)keyPathsForValuesAffectingChangeMonitor;
- (void)setupDefaults;
- (instancetype)copyWithZone:(NSZone *)zone;
- (void)copyIntoOptions:(ASLayoutOptions *)layoutOptions;

#pragma mark - Mutability checks

@property (nonatomic, assign) BOOL isMutable;

#if DEBUG
@property (nonatomic, assign) NSUInteger changeMonitor;
#endif

#pragma mark - ASStackLayoutable

@property (nonatomic, readwrite) CGFloat spacingBefore;
@property (nonatomic, readwrite) CGFloat spacingAfter;
@property (nonatomic, readwrite) BOOL flexGrow;
@property (nonatomic, readwrite) BOOL flexShrink;
@property (nonatomic, readwrite) ASRelativeDimension flexBasis;
@property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf;

#pragma mark - ASBaselineLayoutable

@property (nonatomic, readwrite) CGFloat ascender;
@property (nonatomic, readwrite) CGFloat descender;

#pragma mark - ASStaticLayoutable

@property (nonatomic, readwrite) ASRelativeSizeRange sizeRange;
@property (nonatomic, readwrite) CGPoint layoutPosition;


@end

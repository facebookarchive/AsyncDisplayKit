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
#import <AsyncDisplayKit/ASLayoutSpec.h>

@protocol ASLayoutable;

/**
 *  A store for all of the options defined by ASLayoutSpec subclasses. All implementors of ASLayoutable own a
 *  ASLayoutOptions. When certain layoutSpecs need option values, they are read from this class.
 *
 *  Unless you wish to create a custom layout spec, ASLayoutOptions can largerly be ignored. Instead you can access
 *  the layout option properties exposed in ASLayoutable directly, which will set the values in ASLayoutOptions
 *  behind the scenes.
 */
@interface ASLayoutOptions : NSObject <ASStackLayoutable, ASStaticLayoutable, NSCopying>

/**
 *  Sets the class name for the ASLayoutOptions subclasses that will be created when a node or layoutSpec's options 
 *  are first accessed.
 *
 *  If you create a custom layoutSpec that includes new options, you will want to subclass ASLayoutOptions to add
 *  the new layout options for your layoutSpec(s). In order to make sure your subclass is created instead of an 
 *  instance of ASLayoutOptions, call setDefaultLayoutOptionsClass: early in app launch (applicationDidFinishLaunching:)
 *  with your subclass's class.
 *
 *  @param defaultLayoutOptionsClass The class of ASLayoutOptions that will be lazily created for a node or layout spec.
 */
+ (void)setDefaultLayoutOptionsClass:(Class)defaultLayoutOptionsClass;

/**
 *  @return the Class of ASLayoutOptions that will be created for a node or layoutspec. Defaults to [ASLayoutOptions class];
 */
+ (Class)defaultLayoutOptionsClass;

#pragma mark - Subclasses should implement these!
/**
 *  Initializes a new ASLayoutOptions using the given layoutable to assign any intrinsic option values.
 *  This init function sets a sensible default value for each layout option. If you create a subclass of 
 *  ASLayoutOptions, your subclass should do the same.
 *
 *  @param layoutable The layoutable that will own these options. The layoutable will be used to set any intrinsic
 *         layoutOptions. For example, if the layoutable is an ASTextNode the ascender/descender values will get set.
 *
 *  @return a new instance of ASLayoutOptions
 */
- (instancetype)initWithLayoutable:(id<ASLayoutable>)layoutable;

/**
 *  Copies the values of layoutOptions into self. This is useful when placing a layoutable inside of another. Consider
 *  an ASTextNode that you want to align to the baseline by putting it in an ASStackLayoutSpec. Before that, you want
 *  to inset the ASTextNode by placing it in an ASInsetLayoutSpec. An ASInsetLayoutSpec will not have any information
 *  about the ASTextNode's ascender/descender unless we copy over the layout options from ASTextNode to ASInsetLayoutSpec.
 *  This is done automatically and should not need to be called directly. It is listed here to make sure that any 
 *  ASLayoutOptions subclass implements the method.
 *
 *  @param layoutOptions The layoutOptions to copy from
 */
- (void)copyFromOptions:(ASLayoutOptions *)layoutOptions;

#pragma mark - ASStackLayoutable

@property (nonatomic, readwrite) CGFloat spacingBefore;
@property (nonatomic, readwrite) CGFloat spacingAfter;
@property (nonatomic, readwrite) BOOL flexGrow;
@property (nonatomic, readwrite) BOOL flexShrink;
@property (nonatomic, readwrite) ASRelativeDimension flexBasis;
@property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf;
@property (nonatomic, readwrite) CGFloat ascender;
@property (nonatomic, readwrite) CGFloat descender;

#pragma mark - ASStaticLayoutable

@property (nonatomic, readwrite) ASRelativeSizeRange sizeRange;
@property (nonatomic, readwrite) CGPoint layoutPosition;

@end

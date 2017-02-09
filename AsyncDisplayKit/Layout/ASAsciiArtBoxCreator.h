//
//  ASAsciiArtBoxCreator.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASLayoutElementAsciiArtProtocol <NSObject>
/**
 *  Returns an ascii-art representation of this object and its children.
 *  For example, an ASInsetSpec may return something like this:
 *
 *   --ASInsetLayoutSpec--
 *   |     ASTextNode    |
 *   ---------------------
 */
- (NSString *)asciiArtString;

/**
 *  returns the name of this object that will display in the ascii art. Usually this can
 *  simply be NSStringFromClass([self class]).
 */
- (NSString *)asciiArtName;

@end

/**
 *  A that takes a parent and its children and renders as ascii art box.
 */
@interface ASAsciiArtBoxCreator : NSObject

/**
 *  Renders an ascii art box with the children aligned horizontally
 *  Example:
 *  ------------ASStackLayoutSpec-----------
 *  |  ASTextNode  ASTextNode  ASTextNode  |
 *  ----------------------------------------
 */
+ (NSString *)horizontalBoxStringForChildren:(NSArray<NSString *> *)children parent:(NSString *)parent;

/**
 *  Renders an ascii art box with the children aligned vertically.
 *  Example:
 *   --ASStackLayoutSpec--
 *   |     ASTextNode    |
 *   |     ASTextNode    |
 *   |     ASTextNode    |
 *   ---------------------
 */
+ (NSString *)verticalBoxStringForChildren:(NSArray<NSString *> *)children parent:(NSString *)parent;

@end

NS_ASSUME_NONNULL_END

//
//  ASLayoutElementStylePrivate.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@interface ASLayoutElementStyle () <ASDescriptionProvider>

/**
 * @abstract The object that acts as the delegate of the style.
 *
 * @discussion The delegate must adopt the ASLayoutElementStyleDelegate protocol. The delegate is not retained.
 */
@property (nullable, nonatomic, weak) id<ASLayoutElementStyleDelegate> delegate;

/**
 * @abstract A size constraint that should apply to this ASLayoutElement.
 */
@property (nonatomic, assign, readonly) ASLayoutElementSize size;

@end

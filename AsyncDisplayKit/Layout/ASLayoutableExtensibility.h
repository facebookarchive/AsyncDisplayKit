//
//  ASLayoutableExtensibility.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 3/29/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIGeometry.h>

@protocol ASLayoutableExtensibility <NSObject>

// The maximum number of extended values per type are defined in ASEnvironment.h above the ASEnvironmentStateExtensions
// struct definition. If you try to set a value at an index after the maximum it will throw an assertion.

- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx;
- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx;

- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx;
- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx;

- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx;
- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx;

@end

//
//  ASLayoutableValidationBlockProvider.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

@protocol ASLayoutableValidationBlock;

#pragma mark - ASLayoutableValidatorProvider

/*
 * ASLayoutSpec subclasses can conform to the ASLayoutableValidationBlockProvider and will get automatic
 * layoutable validation based on the layoutableValidatorBlocks
 */
@protocol ASLayoutableValidationBlockProvider <NSObject>

- (NSArray<ASLayoutableValidationBlock> *)layoutableValidatorBlocks;

@end

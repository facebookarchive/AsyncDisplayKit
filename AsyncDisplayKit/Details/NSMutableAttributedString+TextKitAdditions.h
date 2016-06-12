//
//  NSMutableAttributedString+TextKitAdditions.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableAttributedString (TextKitAdditions)

- (void)attributeTextInRange:(NSRange)range withTextKitMinimumLineHeight:(CGFloat)minimumLineHeight;

- (void)attributeTextInRange:(NSRange)range withTextKitMinimumLineHeight:(CGFloat)minimumLineHeight maximumLineHeight:(CGFloat)maximumLineHeight;

- (void)attributeTextInRange:(NSRange)range withTextKitLineHeight:(CGFloat)lineHeight;

- (void)attributeTextInRange:(NSRange)range withTextKitParagraphStyle:(NSParagraphStyle *)paragraphStyle;

@end

NS_ASSUME_NONNULL_END
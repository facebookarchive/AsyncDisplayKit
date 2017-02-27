//
//  ASMutableAttributedStringBuilder.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Use this class to compose new attributed strings.  You may use the normal
 * attributed string calls on this the same way you would on a normal mutable
 * attributed string, but it coalesces your changes into transactions on the
 * actual string allowing improvements in performance.
 *
 * @discussion This is a use-once and throw away class for each string you make.
 * Since this class is designed for increasing performance, we actually hand
 * back the internally managed mutable attributed string in the
 * `composedAttributedString` call.  So once you make that call, any more
 * changes will actually modify the string that was handed back to you in that
 * method.
 *
 * Combination of multiple calls into single attribution is managed through
 * merging of attribute dictionaries over ranges.  For best performance, call
 * collections of attributions over a single range together.  So for instance,
 * don't call addAttributes for range1, then range2, then range1 again.  Group
 * them together so you call addAttributes for both range1 together, and then
 * range2.
 *
 * Also please note that switching between addAttribute and setAttributes in the
 * middle of composition is a bad idea for performance because they have
 * semantically different meanings, and trigger a commit of the pending
 * attributes.
 *
 * Please note that ALL of the standard NSString methods are left unimplemented.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASMutableAttributedStringBuilder : NSMutableAttributedString

- (instancetype)initWithString:(NSString *)str attributes:(nullable NSDictionary<NSString *, id> *)attrs;
- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr;

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str;
- (void)setAttributes:(nullable NSDictionary<NSString *, id> *)attrs range:(NSRange)range;

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary<NSString *, id> *)attrs range:(NSRange)range;
- (void)removeAttribute:(NSString *)name range:(NSRange)range;

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString;
- (void)insertAttributedString:(NSAttributedString *)attrString atIndex:(NSUInteger)loc;
- (void)appendAttributedString:(NSAttributedString *)attrString;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)setAttributedString:(NSAttributedString *)attrString;

- (NSMutableAttributedString *)composedAttributedString;

@end

NS_ASSUME_NONNULL_END

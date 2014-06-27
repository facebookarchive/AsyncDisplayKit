/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASMutableAttributedStringBuilder.h"

@implementation ASMutableAttributedStringBuilder {
  // Flag for the type of the current transaction (set or add)
  BOOL _setRange;
  // The range over which the currently pending transaction will occur
  NSRange _pendingRange;
  // The actual attribute dictionary that is being composed
  NSMutableDictionary *_pendingRangeAttributes;
  NSMutableAttributedString *_attrStr;

  // We delay initialization of the _attrStr until we need to
  NSString *_initString;
}

- (instancetype)init
{
  if (self = [super init]) {
    _attrStr = [[NSMutableAttributedString alloc] init];
    _pendingRange.location = NSNotFound;
  }
  return self;
}

- (instancetype)initWithString:(NSString *)str
{
  return [self initWithString:str attributes:@{}];
}

- (instancetype)initWithString:(NSString *)str attributes:(NSDictionary *)attrs
{
  if (self = [super init]) {
    // We cache this in an ivar that we can lazily construct the attributed
    // string with when we get to a forced commit point.
    _initString = str;
    // Triggers a creation of the _pendingRangeAttributes dictionary which then
    // is filled with entries from the given attrs dict.
    [[self _pendingRangeAttributes] addEntriesFromDictionary:attrs];
    _setRange = NO;
    _pendingRange = NSMakeRange(0, _initString.length);
  }
  return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr
{
  if (self = [super init]) {
    _attrStr = [[NSMutableAttributedString alloc] initWithAttributedString:attrStr];
    _pendingRange.location = NSNotFound;
  }
  return self;
}

- (NSMutableAttributedString *)_attributedString
{
  if (_attrStr == nil && _initString != nil) {
    // We can lazily construct the attributed string if it hasn't already been
    // created with the existing pending attributes.  This is significantly
    // faster if more attributes are added after initializing this instance
    // and the new attributions are for the entire string anyway.
    _attrStr = [[NSMutableAttributedString alloc] initWithString:_initString attributes:_pendingRangeAttributes];
    _pendingRangeAttributes = nil;
    _pendingRange.location = NSNotFound;
    _initString = nil;
  }

  return _attrStr;
}

#pragma mark - Pending attribution

- (NSMutableDictionary *)_pendingRangeAttributes
{
  // Lazy dictionary creation.  Call this if you want to force initialization,
  // otherwise just use the ivar.
  if (_pendingRangeAttributes == nil) {
    _pendingRangeAttributes = [[NSMutableDictionary alloc] init];
  }
  return _pendingRangeAttributes;
}

- (void)_applyPendingRangeAttributions
{
  if (_attrStr == nil) {
    // Trigger its creation if it doesn't exist.
    [self _attributedString];
  }

  if (_pendingRangeAttributes.count == 0) {
    return;
  }

  if (_pendingRange.location == NSNotFound) {
    return;
  }

  if (_setRange) {
    [[self _attributedString] setAttributes:_pendingRangeAttributes range:_pendingRange];
  } else {
    [[self _attributedString] addAttributes:_pendingRangeAttributes range:_pendingRange];
  }
  _pendingRangeAttributes = nil;
  _pendingRange.location = NSNotFound;
}

#pragma mark - Editing

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
  [self _applyPendingRangeAttributions];
  [[self _attributedString] replaceCharactersInRange:range withString:str];
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString
{
  [self _applyPendingRangeAttributions];
  [[self _attributedString] replaceCharactersInRange:range withAttributedString:attrString];
}

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range
{
  if (_setRange) {
    [self _applyPendingRangeAttributions];
    _setRange = NO;
  }

  if (!NSEqualRanges(_pendingRange, range)) {
    [self _applyPendingRangeAttributions];
    _pendingRange = range;
  }

  NSMutableDictionary *pendingAttributes = [self _pendingRangeAttributes];
  pendingAttributes[name] = value;
}

- (void)addAttributes:(NSDictionary *)attrs range:(NSRange)range
{
  if (_setRange) {
    [self _applyPendingRangeAttributions];
    _setRange = NO;
  }

  if (!NSEqualRanges(_pendingRange, range)) {
    [self _applyPendingRangeAttributions];
    _pendingRange = range;
  }

  NSMutableDictionary *pendingAttributes = [self _pendingRangeAttributes];
  [pendingAttributes addEntriesFromDictionary:attrs];
}

- (void)insertAttributedString:(NSAttributedString *)attrString atIndex:(NSUInteger)loc
{
  [self _applyPendingRangeAttributions];
  [[self _attributedString] insertAttributedString:attrString atIndex:loc];
}

- (void)appendAttributedString:(NSAttributedString *)attrString
{
  [self _applyPendingRangeAttributions];
  [[self _attributedString] appendAttributedString:attrString];
}

- (void)deleteCharactersInRange:(NSRange)range
{
  [self _applyPendingRangeAttributions];
  [[self _attributedString] deleteCharactersInRange:range];
}

- (void)setAttributedString:(NSAttributedString *)attrString
{
  [self _applyPendingRangeAttributions];
  [[self _attributedString] setAttributedString:attrString];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
  if (!_setRange) {
    [self _applyPendingRangeAttributions];
    _setRange = YES;
  }

  if (!NSEqualRanges(_pendingRange, range)) {
    [self _applyPendingRangeAttributions];
    _pendingRange = range;
  }

  NSMutableDictionary *pendingAttributes = [self _pendingRangeAttributes];
  [pendingAttributes addEntriesFromDictionary:attrs];
}

- (void)removeAttribute:(NSString *)name range:(NSRange)range
{
  // This call looks like the other set/add functions, but in order for this
  // function to perform as advertised we MUST first add the attributes we
  // currently have pending.
  [self _applyPendingRangeAttributions];

  [[self _attributedString] removeAttribute:name range:range];
}

#pragma mark - Output

- (NSMutableAttributedString *)composedAttributedString
{
  if (_pendingRangeAttributes.count > 0) {
    [self _applyPendingRangeAttributions];
  }
  return [self _attributedString];
}

#pragma mark - Forwarding

- (NSUInteger)length
{
  // If we just want a length call, no need to lazily construct the attributed string
  return _attrStr ? _attrStr.length : _initString.length;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
  return [[self _attributedString] attributesAtIndex:location effectiveRange:range];
}

- (NSString *)string
{
  return _attrStr ? _attrStr.string : _initString;
}

- (NSMutableString *)mutableString
{
  return [[self _attributedString] mutableString];
}

- (void)beginEditing
{
  [[self _attributedString] beginEditing];
}

- (void)endEditing
{
  [[self _attributedString] endEditing];
}

@end

//
//  ASTextKitContext.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTextKitContext.h>
#import <AsyncDisplayKit/ASLayoutManager.h>
#import <AsyncDisplayKit/ASThread.h>

#include <memory>

@implementation ASTextKitContext
{
  // All TextKit operations (even non-mutative ones) must be executed serially.
  std::shared_ptr<ASDN::Mutex> __instanceLock__;

  NSLayoutManager *_layoutManager;
  NSTextStorage *_textStorage;
  NSTextContainer *_textContainer;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                           lineBreakMode:(NSLineBreakMode)lineBreakMode
                    maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                          exclusionPaths:(NSArray *)exclusionPaths
                         constrainedSize:(CGSize)constrainedSize

{
  if (self = [super init]) {
    // Concurrently initialising TextKit components crashes (rdar://18448377) so we use a global lock.
    static ASDN::Mutex __staticMutex;
    ASDN::MutexLocker l(__staticMutex);
    
    __instanceLock__ = std::make_shared<ASDN::Mutex>();
    
    // Create the TextKit component stack with our default configuration.
    
    _textStorage = [[NSTextStorage alloc] init];
    _layoutManager = [[ASLayoutManager alloc] init];
    _layoutManager.usesFontLeading = NO;
    [_textStorage addLayoutManager:_layoutManager];
    
    // Instead of calling [NSTextStorage initWithAttributedString:], setting attributedString just after calling addlayoutManager can fix CJK language layout issues.
    // See https://github.com/facebook/AsyncDisplayKit/issues/2894
    if (attributedString) {
      [_textStorage setAttributedString:attributedString];
    }
    
    _textContainer = [[NSTextContainer alloc] initWithSize:constrainedSize];
    // We want the text laid out up to the very edges of the container.
    _textContainer.lineFragmentPadding = 0;
    _textContainer.lineBreakMode = lineBreakMode;
    _textContainer.maximumNumberOfLines = maximumNumberOfLines;
    _textContainer.exclusionPaths = exclusionPaths;
    [_layoutManager addTextContainer:_textContainer];
  }
  return self;
}

- (void)performBlockWithLockedTextKitComponents:(void (^)(NSLayoutManager *,
                                                          NSTextStorage *,
                                                          NSTextContainer *))block
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  if (block) {
    block(_layoutManager, _textStorage, _textContainer);
  }
}

@end

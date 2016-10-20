//
//  ASTextKitContext.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

/**
 A threadsafe container for the TextKit components that ASTextKit uses to lay out and truncate its text.

 This container is the sole owner and manager of the TextKit classes.  This is an important model because of major
 thread safety issues inside vanilla TextKit.  It provides a central locking location for accessing TextKit methods.
 */
@interface ASTextKitContext : NSObject

/**
 Initializes a context and its associated TextKit components.

 Initialization of TextKit components is a globally locking operation so be careful of bottlenecks with this class.
 */
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                           lineBreakMode:(NSLineBreakMode)lineBreakMode
                    maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                          exclusionPaths:(NSArray *)exclusionPaths
                         constrainedSize:(CGSize)constrainedSize;

@property (nonatomic, assign, readwrite) CGSize constrainedSize;

/**
 All operations on TextKit values MUST occur within this locked context.  Simultaneous access (even non-mutative) to
 TextKit components may cause crashes.

 The block provided MUST not call out to client code from within its scope or it is possible for this to cause deadlocks
 in your application.  Use with EXTREME care.

 Callers MUST NOT keep a ref to these internal objects and use them later.  This WILL cause crashes in your application.
 */
- (void)performBlockWithLockedTextKitComponents:(void (^)(NSLayoutManager *layoutManager,
                                                          NSTextStorage *textStorage,
                                                          NSTextContainer *textContainer))block;

@end

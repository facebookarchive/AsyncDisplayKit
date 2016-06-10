//
//  ASDealloc2MainObject.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDealloc2MainObject.h"

#import <pthread.h>

#import "_AS-objc-internal.h"

#if __has_feature(objc_arc)
#error This file must be compiled without ARC. Use -fno-objc-arc.
#endif

@interface ASDealloc2MainObject ()
{
  @private
  int _retainCount;
}
@end

@implementation ASDealloc2MainObject

#if !__has_feature(objc_arc)
_OBJC_SUPPORTED_INLINE_REFCNT_WITH_DEALLOC2MAIN(_retainCount);
#endif

@end

//
//  ASLog.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import <sys/kdebug_signpost.h>
#import "ASAvailability.h"

#define ASMultiplexImageNodeLogDebug(...)
#define ASMultiplexImageNodeCLogDebug(...)

#define ASMultiplexImageNodeLogError(...)
#define ASMultiplexImageNodeCLogError(...)

#if PROFILE
// These definitions are required to build the backward-compatible kdebug trace
// on the iOS 10 SDK.  The kdebug_trace function crashes if run on iOS 9 and earlier.
// It's valuable to support trace signposts on iOS 9, because A5 devices don't support iOS 10.
#ifndef DBG_MACH_CHUD
#define DBG_MACH_CHUD 0x0A
#define DBG_FUNC_START 1
#define DBG_FUNC_END 2
#define DBG_APPS 33
#define SYS_kdebug_trace 180
#define KDBG_CODE(Class, SubClass, code) (((Class & 0xff) << 24) | ((SubClass & 0xff) << 16) | ((code & 0x3fff)  << 2))
#define APPSDBG_CODE(SubClass,code) KDBG_CODE(DBG_APPS, SubClass, code)
#endif

#define ASProfilingSignpost(x) \
  AS_AT_LEAST_IOS10 ? kdebug_signpost(x, 0, 0, 0, (uint32_t)(x % 4)) \
                    : syscall(SYS_kdebug_trace, APPSDBG_CODE(DBG_MACH_CHUD, x) | DBG_FUNC_NONE, 0, 0, 0, (uint32_t)(x % 4));

#define ASProfilingSignpostStart(x, y) \
  AS_AT_LEAST_IOS10 ? kdebug_signpost_start((uint32_t)x, (uintptr_t)y, 0, 0, (uint32_t)(x % 4)) \
                    : syscall(SYS_kdebug_trace, APPSDBG_CODE(DBG_MACH_CHUD, x) | DBG_FUNC_START, (uintptr_t)y, 0, 0, (uint32_t)(x % 4));

#define ASProfilingSignpostEnd(x, y) \
  AS_AT_LEAST_IOS10 ? kdebug_signpost_end((uint32_t)x, (uintptr_t)y, 0, 0, (uint32_t)(x % 4)) \
                    : syscall(SYS_kdebug_trace, APPSDBG_CODE(DBG_MACH_CHUD, x) | DBG_FUNC_END, (uintptr_t)y, 0, 0, (uint32_t)(x % 4));
#else

#define ASProfilingSignpost(x)
#define ASProfilingSignpostStart(x, y)
#define ASProfilingSignpostEnd(x, y)

#endif

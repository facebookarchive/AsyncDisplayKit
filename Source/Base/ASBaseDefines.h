//
//  ASBaseDefines.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import <AsyncDisplayKit/ASLog.h>

// The C++ compiler mangles C function names. extern "C" { /* your C functions */ } prevents this.
// You should wrap all C function prototypes declared in headers with ASDISPLAYNODE_EXTERN_C_BEGIN/END, even if
// they are included only from .m (Objective-C) files. It's common for .m files to start using C++
// features and become .mm (Objective-C++) files. Always wrapping the prototypes with
// ASDISPLAYNODE_EXTERN_C_BEGIN/END will save someone a headache once they need to do this. You do not need to
// wrap constants, only C functions. See StackOverflow for more details:
// http://stackoverflow.com/questions/1041866/in-c-source-what-is-the-effect-of-extern-c
#ifdef __cplusplus
# define ASDISPLAYNODE_EXTERN_C_BEGIN extern "C" {
# define ASDISPLAYNODE_EXTERN_C_END   }
#else
# define ASDISPLAYNODE_EXTERN_C_BEGIN
# define ASDISPLAYNODE_EXTERN_C_END
#endif

#ifdef __GNUC__
# define ASDISPLAYNODE_GNUC(major, minor) \
(__GNUC__ > (major) || (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#else
# define ASDISPLAYNODE_GNUC(major, minor) 0
#endif

#ifndef ASDISPLAYNODE_INLINE
# if defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#  define ASDISPLAYNODE_INLINE static inline
# elif defined (__MWERKS__) || defined (__cplusplus)
#  define ASDISPLAYNODE_INLINE static inline
# elif ASDISPLAYNODE_GNUC (3, 0)
#  define ASDISPLAYNODE_INLINE static __inline__ __attribute__ ((always_inline))
# else
#  define ASDISPLAYNODE_INLINE static
# endif
#endif

#ifndef ASDISPLAYNODE_HIDDEN
# if ASDISPLAYNODE_GNUC (4,0)
#  define ASDISPLAYNODE_HIDDEN __attribute__ ((visibility ("hidden")))
# else
#  define ASDISPLAYNODE_HIDDEN /* no hidden */
# endif
#endif

#ifndef ASDISPLAYNODE_PURE
# if ASDISPLAYNODE_GNUC (3, 0)
#  define ASDISPLAYNODE_PURE __attribute__ ((pure))
# else
#  define ASDISPLAYNODE_PURE /* no pure */
# endif
#endif

#ifndef ASDISPLAYNODE_CONST
# if ASDISPLAYNODE_GNUC (3, 0)
#  define ASDISPLAYNODE_CONST __attribute__ ((const))
# else
#  define ASDISPLAYNODE_CONST /* no const */
# endif
#endif

#ifndef ASDISPLAYNODE_WARN_UNUSED
# if ASDISPLAYNODE_GNUC (3, 4)
#  define ASDISPLAYNODE_WARN_UNUSED __attribute__ ((warn_unused_result))
# else
#  define ASDISPLAYNODE_WARN_UNUSED /* no warn_unused */
# endif
#endif

#ifndef ASDISPLAYNODE_WARN_DEPRECATED
# define ASDISPLAYNODE_WARN_DEPRECATED 1
#endif

#ifndef ASDISPLAYNODE_DEPRECATED
# if ASDISPLAYNODE_GNUC (3, 0) && ASDISPLAYNODE_WARN_DEPRECATED
#  define ASDISPLAYNODE_DEPRECATED __attribute__ ((deprecated))
# else
#  define ASDISPLAYNODE_DEPRECATED
# endif
#endif

#ifndef ASDISPLAYNODE_DEPRECATED_MSG
# if ASDISPLAYNODE_GNUC (3, 0) && ASDISPLAYNODE_WARN_DEPRECATED
#   define  ASDISPLAYNODE_DEPRECATED_MSG(msg) __deprecated_msg(msg)
# else
#   define  ASDISPLAYNODE_DEPRECATED_MSG(msg)
# endif
#endif

#if defined (__cplusplus) && defined (__GNUC__)
# define ASDISPLAYNODE_NOTHROW __attribute__ ((nothrow))
#else
# define ASDISPLAYNODE_NOTHROW
#endif

/**
 * The event backtraces take a static 2KB of memory
 * and retain all objects present in all the registers
 * of the stack frames. The memory consumption impact
 * is too significant even to be enabled during general
 * development.
 */
#ifndef AS_SAVE_EVENT_BACKTRACES
# define AS_SAVE_EVENT_BACKTRACES 0
#endif

#define ARRAY_COUNT(x) sizeof(x) / sizeof(x[0])

#ifndef __has_feature      // Optional.
#define __has_feature(x) 0 // Compatibility with non-clang compilers.
#endif

#ifndef __has_attribute      // Optional.
#define __has_attribute(x) 0 // Compatibility with non-clang compilers.
#endif

#ifndef NS_CONSUMED
#if __has_feature(attribute_ns_consumed)
#define NS_CONSUMED __attribute__((ns_consumed))
#else
#define NS_CONSUMED
#endif
#endif

#ifndef NS_RETURNS_RETAINED
#if __has_feature(attribute_ns_returns_retained)
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#else
#define NS_RETURNS_RETAINED
#endif
#endif

#ifndef CF_RETURNS_RETAINED
#if __has_feature(attribute_cf_returns_retained)
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#else
#define CF_RETURNS_RETAINED
#endif
#endif

#ifndef ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER
#define ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER() \
  do { \
    NSAssert2(NO, @"%@ is not the designated initializer for instances of %@.", NSStringFromSelector(_cmd), NSStringFromClass([self class])); \
    return nil; \
  } while (0)
#endif // ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER

// It's hard to pass quoted strings via xcodebuild preprocessor define arguments, so we'll convert
// the preprocessor values to strings here.
//
// It takes two steps to do this in gcc as per
// http://gcc.gnu.org/onlinedocs/cpp/Stringification.html
#define ASDISPLAYNODE_TO_STRING(str) #str
#define ASDISPLAYNODE_TO_UNICODE_STRING(str) @ASDISPLAYNODE_TO_STRING(str)

#ifndef ASDISPLAYNODE_REQUIRES_SUPER
#if __has_attribute(objc_requires_super)
#define ASDISPLAYNODE_REQUIRES_SUPER __attribute__((objc_requires_super))
#else
#define ASDISPLAYNODE_REQUIRES_SUPER
#endif
#endif

#ifndef AS_UNAVAILABLE
#if __has_attribute(unavailable)
#define AS_UNAVAILABLE(message) __attribute__((unavailable(message)))
#else
#define AS_UNAVAILABLE(message)
#endif
#endif

#ifndef AS_WARN_UNUSED_RESULT
#if __has_attribute(warn_unused_result)
#define AS_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#else
#define AS_WARN_UNUSED_RESULT
#endif
#endif

#define ASOVERLOADABLE __attribute__((overloadable))


#if __has_attribute(noescape)
#define AS_NOESCAPE __attribute__((noescape))
#else
#define AS_NOESCAPE
#endif

#if __has_attribute(objc_subclassing_restricted)
#define AS_SUBCLASSING_RESTRICTED __attribute__((objc_subclassing_restricted))
#else
#define AS_SUBCLASSING_RESTRICTED
#endif

/// Ensure that class is of certain kind
#define ASDynamicCast(x, c) ({ \
  id __val = x;\
  ((c *) ([__val isKindOfClass:[c class]] ? __val : nil));\
})

/**
 * Create a new set by mapping `collection` over `work`, ignoring nil.
 */
#define ASSetByFlatMapping(collection, decl, work) ({ \
  NSMutableSet *s = [NSMutableSet set]; \
  for (decl in collection) {\
    id result = work; \
    if (result != nil) { \
      [s addObject:result]; \
    } \
  } \
  s; \
})

/**
 * Create a new array by mapping `collection` over `work`, ignoring nil.
 */
#define ASArrayByFlatMapping(collection, decl, work) ({ \
  NSMutableArray *a = [NSMutableArray array]; \
  for (decl in collection) {\
    id result = work; \
    if (result != nil) { \
      [a addObject:result]; \
    } \
  } \
  a; \
})

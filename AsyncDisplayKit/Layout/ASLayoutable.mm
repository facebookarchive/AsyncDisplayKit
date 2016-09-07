//
//  ASLayoutable.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/27/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutablePrivate.h"
#import "ASEnvironmentInternal.h"
#import "ASDisplayNodeInternal.h"

#import <map>

int32_t const ASLayoutableContextInvalidTransitionID = 0;
int32_t const ASLayoutableContextDefaultTransitionID = ASLayoutableContextInvalidTransitionID + 1;

static inline ASLayoutableContext _ASLayoutableContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  struct ASLayoutableContext context;
  context.transitionID = transitionID;
  context.needsVisualizeNode = needsVisualizeNode;
  return context;
}

static inline BOOL _IsValidTransitionID(int32_t transitionID)
{
  return transitionID > ASLayoutableContextInvalidTransitionID;
}

struct ASLayoutableContext const ASLayoutableContextNull = _ASLayoutableContextMake(ASLayoutableContextInvalidTransitionID, NO);

BOOL ASLayoutableContextIsNull(struct ASLayoutableContext context)
{
  return !_IsValidTransitionID(context.transitionID);
}

ASLayoutableContext ASLayoutableContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  NSCAssert(_IsValidTransitionID(transitionID), @"Invalid transition ID");
  return _ASLayoutableContextMake(transitionID, needsVisualizeNode);
}

// Note: This is a non-recursive static lock. If it needs to be recursive, use ASDISPLAYNODE_MUTEX_RECURSIVE_INITIALIZER
static ASDN::StaticMutex _layoutableContextLock = ASDISPLAYNODE_MUTEX_INITIALIZER;
static std::map<mach_port_t, ASLayoutableContext> layoutableContextMap;

static inline mach_port_t ASLayoutableGetCurrentContextKey()
{
  return pthread_mach_thread_np(pthread_self());
}

void ASLayoutableSetCurrentContext(struct ASLayoutableContext context)
{
  const mach_port_t key = ASLayoutableGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutableContextLock);
  layoutableContextMap[key] = context;
}

struct ASLayoutableContext ASLayoutableGetCurrentContext()
{
  const mach_port_t key = ASLayoutableGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutableContextLock);
  const auto it = layoutableContextMap.find(key);
  if (it != layoutableContextMap.end()) {
    // Found an interator with above key. "it->first" is the key itself, "it->second" is the context value.
    return it->second;
  }
  return ASLayoutableContextNull;
}

void ASLayoutableClearCurrentContext()
{
  const mach_port_t key = ASLayoutableGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutableContextLock);
  layoutableContextMap.erase(key);
}

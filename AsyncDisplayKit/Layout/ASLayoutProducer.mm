//
//  ASLayoutProducerPrivate.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutProducerPrivate.h"
#import "ASInternalHelpers.h"
#import "ASEnvironmentInternal.h"
#import "ASDisplayNodeInternal.h"
#import "ASTextNode.h"
#import "ASLayoutSpec.h"

#import "pthread.h"
#import <map>
#import <iterator>
#import "ASThread.h"

int32_t const ASLayoutProducerContextInvalidTransitionID = 0;
int32_t const ASLayoutProducerContextDefaultTransitionID = ASLayoutProducerContextInvalidTransitionID + 1;

static inline ASLayoutProducerContext _ASLayoutProducerContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  struct ASLayoutProducerContext context;
  context.transitionID = transitionID;
  context.needsVisualizeNode = needsVisualizeNode;
  return context;
}

static inline BOOL _IsValidTransitionID(int32_t transitionID)
{
  return transitionID > ASLayoutProducerContextInvalidTransitionID;
}

struct ASLayoutProducerContext const ASLayoutProducerContextNull = _ASLayoutProducerContextMake(ASLayoutProducerContextInvalidTransitionID, NO);

BOOL ASLayoutProducerContextIsNull(struct ASLayoutProducerContext context)
{
  return !_IsValidTransitionID(context.transitionID);
}

ASLayoutProducerContext ASLayoutProducerContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  NSCAssert(_IsValidTransitionID(transitionID), @"Invalid transition ID");
  return _ASLayoutProducerContextMake(transitionID, needsVisualizeNode);
}

// Note: This is a non-recursive static lock. If it needs to be recursive, use ASDISPLAYNODE_MUTEX_RECURSIVE_INITIALIZER
static ASDN::StaticMutex _producerContextLock = ASDISPLAYNODE_MUTEX_INITIALIZER;
static std::map<mach_port_t, ASLayoutProducerContext> producerContextMap;

static inline mach_port_t ASLayoutProducerGetCurrentContextKey()
{
  return pthread_mach_thread_np(pthread_self());
}

void ASLayoutProducerSetCurrentContext(struct ASLayoutProducerContext context)
{
  const mach_port_t key = ASLayoutProducerGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_producerContextLock);
  producerContextMap[key] = context;
}

struct ASLayoutProducerContext ASLayoutProducerGetCurrentContext()
{
  const mach_port_t key = ASLayoutProducerGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_producerContextLock);
  const auto it = producerContextMap.find(key);
  if (it != producerContextMap.end()) {
    // Found an interator with above key. "it->first" is the key itself, "it->second" is the context value.
    return it->second;
  }
  return ASLayoutProducerContextNull;
}

void ASLayoutProducerClearCurrentContext()
{
  const mach_port_t key = ASLayoutProducerGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_producerContextLock);
  producerContextMap.erase(key);
}

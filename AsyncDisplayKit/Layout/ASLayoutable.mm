//
//  ASLayoutablePrivate.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutablePrivate.h"
#import "pthread.h"
#import <map>

ASLayoutableContext ASLayoutableContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  struct ASLayoutableContext context;
  context.transitionID = transitionID;
  context.needsVisualizeNode = needsVisualizeNode;
  return context;
}

static std::map<mach_port_t, ASLayoutableContext> layoutableContextMap;

static inline mach_port_t ASLayoutableGetCurrentContextKey()
{
  return pthread_mach_thread_np(pthread_self());
}

void ASLayoutableSetCurrentContext(struct ASLayoutableContext context)
{
  layoutableContextMap[ASLayoutableGetCurrentContextKey()] = context;
}

struct ASLayoutableContext ASLayoutableGetCurrentContext()
{
  return layoutableContextMap[ASLayoutableGetCurrentContextKey()];
}

void ASLayoutableClearCurrentContext() {
  layoutableContextMap.erase(ASLayoutableGetCurrentContextKey());
}

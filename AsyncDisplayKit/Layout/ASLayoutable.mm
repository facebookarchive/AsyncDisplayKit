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

static inline mach_port_t ASLayoutableGetLayoutableContextKey()
{
  return pthread_mach_thread_np(pthread_self());
}

void ASLayoutableSetLayoutableContext(struct ASLayoutableContext context)
{
  layoutableContextMap[ASLayoutableGetLayoutableContextKey()] = context;
}

struct ASLayoutableContext ASLayoutableGetLayoutableContext()
{
  return layoutableContextMap[ASLayoutableGetLayoutableContextKey()];
}

void ASLayoutableResetLayoutableContext() {
  layoutableContextMap.erase(ASLayoutableGetLayoutableContextKey());
}

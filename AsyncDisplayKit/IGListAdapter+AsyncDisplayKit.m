//
//  IGListAdapter+AsyncDisplayKit.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import "IGListAdapter+AsyncDisplayKit.h"
#import "ASListAdapter.h"
#import "ASListAdapterImpl.h"
#import "ASAssert.h"
#import <objc/runtime.h>

@implementation IGListAdapter (AsyncDisplayKit)

- (id<ASListAdapter>)as_dataAdapter
{
  ASDisplayNodeAssertMainThread();

  ASListAdapterImpl *adapter = objc_getAssociatedObject(self, _cmd);
  if (adapter == nil) {
    adapter = [[ASListAdapterImpl alloc] init];
    objc_setAssociatedObject(self, _cmd, adapter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return adapter;
}

@end

#endif // IG_LIST_KIT

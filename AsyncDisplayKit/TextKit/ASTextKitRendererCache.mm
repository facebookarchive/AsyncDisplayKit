//
//  ASTextKitRendererCache.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTextKitRendererCache.h"
#import "ASEqualityHashHelpers.h"
#import "ASTextKitAttributes.h"

namespace ASDK {
  namespace TextKit {
    void lowMemoryNotificationHandler(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
      // Compaction is a relatively cheap operation and it's important that we get it done ASAP, so use the high-pri queue.
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        (static_cast<ApplicationObserver *>(observer))->onLowMemory();
      });
    }
    void enteredBackgroundNotificationHandler(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
      (static_cast<ApplicationObserver *>(observer))->onEnterBackground();
    }
    
    namespace Renderer {
      Key::Key(ASTextKitAttributes a, CGSize cs) : attributes(a), constrainedSize(cs) {
        // Precompute hash to avoid paying cost every time getHash is called.
        NSUInteger subhashes[] = {
          attributes.hash(),
          std::hash<CGFloat>()(constrainedSize.width),
          std::hash<CGFloat>()(constrainedSize.height)
        };
        hash = ASIntegerArrayHash(subhashes, sizeof(subhashes) / sizeof(subhashes[0]));
      }
    }
  }
}

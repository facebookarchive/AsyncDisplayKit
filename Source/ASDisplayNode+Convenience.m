//
//  ASDisplayNode+Convenience.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/24/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDisplayNode+Convenience.h"

#import <UIKit/UIViewController.h>

#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASResponderChainEnumerator.h>

@implementation ASDisplayNode (Convenience)

- (__kindof UIViewController *)closestViewController
{
  ASDisplayNodeAssertMainThread();
  
  // Careful not to trigger node loading here.
  if (!self.nodeLoaded) {
    return nil;
  }

  // Get the closest view.
  UIView *view = ASFindClosestViewOfLayer(self.layer);
  // Travel up the responder chain to find a view controller.
  for (UIResponder *responder in [view asdk_responderChainEnumerator]) {
    UIViewController *vc = ASDynamicCast(responder, UIViewController);
    if (vc != nil) {
      return vc;
    }
  }
  return nil;
}

@end

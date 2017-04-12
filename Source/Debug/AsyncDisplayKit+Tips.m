//
//  AsyncDisplayKit+Tips.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "AsyncDisplayKit+Tips.h"
#import <AsyncDisplayKit/ASDisplayNode+Ancestry.h>

@implementation ASDisplayNode (Tips)

static char ASDisplayNodeEnableTipsKey;
static ASTipDisplayBlock _Nullable __tipDisplayBlock;

/**
 * Use associated objects with NSNumbers. This is a debug property - simplicity is king.
 */
+ (void)setEnableTips:(BOOL)enableTips
{
  objc_setAssociatedObject(self, &ASDisplayNodeEnableTipsKey, @(enableTips), OBJC_ASSOCIATION_COPY);
}

+ (BOOL)enableTips
{
  NSNumber *result = objc_getAssociatedObject(self, &ASDisplayNodeEnableTipsKey);
  if (result == nil) {
    return YES;
  }
  return result.boolValue;
}


+ (void)setTipDisplayBlock:(ASTipDisplayBlock)tipDisplayBlock
{
  __tipDisplayBlock = tipDisplayBlock;
}

+ (ASTipDisplayBlock)tipDisplayBlock
{
  return __tipDisplayBlock ?: ^(ASDisplayNode *node, NSString *string) {
    NSLog(@"%@. Node ancestry: %@", string, node.ancestryDescription);
  };
}

@end

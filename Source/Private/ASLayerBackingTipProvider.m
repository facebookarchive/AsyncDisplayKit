//
//  ASLayerBackingTipProvider.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASLayerBackingTipProvider.h"

#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASTip.h>

@implementation ASLayerBackingTipProvider

- (ASTip *)tipForNode:(ASDisplayNode *)node
{
  // Already layer-backed.
  if (node.layerBacked) {
    return nil;
  }

  // TODO: Avoid revisiting nodes we already visited
  ASDisplayNode *failNode = ASDisplayNodeFindFirstNode(node, ^BOOL(ASDisplayNode * _Nonnull node) {
    return !node.supportsLayerBacking;
  });
  if (failNode != nil) {
    return nil;
  }

  ASTip *result = [[ASTip alloc] initWithNode:node
                                         kind:ASTipKindEnableLayerBacking
                                       format:@"Enable layer backing to improve performance"];
  return result;
}

@end

#endif // AS_ENABLE_TIPS

//
//  ASLayoutNodeTestsHelper.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/05/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASSnapshotTestCase.h"

@class ASLayoutNode;

@interface ASLayoutNodeSnapshotTestCase: ASSnapshotTestCase
/**
 Test the layout node or records a snapshot if recordMode is YES.
 @param layoutNode The layout node under test or to snapshot
 @param sizeRange The size range used to calculate layout of the given layout node.
 @param subnodes An array of ASDisplayNodes used within the layout node.
 @param identifier An optional identifier, used to identify this snapshot test.
 
 @discussion In order to make the layout node visible, it is embeded to a ASDisplayNode host.
 Any display nodes used within the layout must be provided.
 They will be added to the host in the same order as the subnodes array.
 */
- (void)testLayoutNode:(ASLayoutNode *)layoutNode
             sizeRange:(ASSizeRange)sizeRange
              subnodes:(NSArray *)subnodes
            identifier:(NSString *)identifier;
@end

@interface ASStaticSizeDisplayNode : ASDisplayNode

@property (nonatomic) CGSize staticSize;

@end

static inline ASStaticSizeDisplayNode *ASDisplayNodeWithBackgroundColor(UIColor *backgroundColor)
{
  ASStaticSizeDisplayNode *node = [[ASStaticSizeDisplayNode alloc] init];
  node.layerBacked = YES;
  node.backgroundColor = backgroundColor;
  node.staticSize = CGSizeZero;
  return node;
}

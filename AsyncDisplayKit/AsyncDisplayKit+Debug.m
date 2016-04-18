//
//  AsyncDisplayKit+Debug.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AsyncDisplayKit+Debug.h"
#import "ASDisplayNode+Subclasses.h"

static BOOL __enableHierarchyCountLabel = NO;
static BOOL __shouldShowImageScalingOverlay = NO;

@implementation ASImageNode (Debugging)

+ (void)setShouldShowImageScalingOverlay:(BOOL)show;
{
  __shouldShowImageScalingOverlay = show;
}

+ (BOOL)shouldShowImageScalingOverlay
{
  return __shouldShowImageScalingOverlay;
}

@end

@implementation ASRangeHierarchyCountInfo

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.textNode = [[ASTextNode alloc] init];
    self.textNode.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.5];
  }
  return self;
}

@end

@implementation ASRangeController (Debug)

+ (void)setHierarchyCountDebugEnabled:(BOOL)enable
{
  __enableHierarchyCountLabel = enable;
}

+ (BOOL)shouldShowHierarchyDebugCountsOverlay
{
  return __enableHierarchyCountLabel;
}

+ (void)updateRangeHierarchyCountInfo:(ASRangeHierarchyCountInfo *)info
{
  NSString *debugString = [NSString stringWithFormat:@"%li N %li L", (long)info.nodeCount, (long)info.layerCount];
  
  // only show # of views if different from # of nodes
  if (info.nodeCount != info.viewCount) {
    debugString = [debugString stringByAppendingString:[NSString stringWithFormat:@" %li V", (long)info.viewCount]];
  }
  info.textNode.attributedString = [[NSAttributedString alloc] initWithString:debugString];
  
  CGRect frame = [info.textNode frame];
  CGSize newSize = [info.textNode measure:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  frame.origin.x += (frame.size.width - newSize.width);
  info.textNode.frame = frame;
}

// debug recursive method that adds or subtracts to the _globalDebug<Node,View,Layer>Count instance variables.
+ (void)debugCountsForAllSubnodes:(ASCellNode *)node increment:(BOOL)increment rangeHierarchyCountInfo:(ASRangeHierarchyCountInfo *)info
{
  if ([node subnodes]) {
    for (ASCellNode *subnode in [node subnodes]) {
      [self debugCountsForAllSubnodes:subnode increment:increment rangeHierarchyCountInfo:info];
    }
  } else {
    [self debugCountsForNode:node increment:increment rangeHierarchyCountInfo:info];
  }
}

+ (void)debugCountsForNode:(ASCellNode *)node increment:(BOOL)increment rangeHierarchyCountInfo:(ASRangeHierarchyCountInfo *)info
{
  if (increment) {
    // add to counts - used in willDisplayCell:foritemAtIndexPath:
    info.nodeCount++;
    if (node.isLayerBacked) {
      info.layerCount++;
    } else {
      info.viewCount++;
      info.layerCount++;
    }
  } else {
    // decrement counts - used in didEndDisplayingCell:forItemAtIndexPath:
    info.nodeCount--;
    if (node.isLayerBacked) {
      info.layerCount--;
    } else {
      info.viewCount--;
      info.layerCount--;
    }
  }
}

@end

//
//  ViewController.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ViewController.h"
#import "PlaygroundContainerNode.h"
#import "ASLayoutableInspectorNode.h"

@interface ViewController () <ASPagerNodeDataSource, ASLayoutableInspectorNodeDelegate, PlaygroundContainerNodeDelegate>
@end

@implementation ViewController
{
  ASPagerNode *_pagerNode;
  ASSizeRange _sizeRange;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  _pagerNode = [[ASPagerNode alloc] init];
  self = [super initWithNode:_pagerNode];
  
  if (self) {
    _pagerNode.dataSource = self;
    self.navigationItem.title   = @"ASLayoutSpec Playground";
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [ASLayoutableInspectorNode sharedInstance].delegate = self;
  }
  
  return self;
}

#pragma mark - ASPagerNodeDataSource

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 2;
}

- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index
{
  return ^{
    PlaygroundContainerNode *containerCellNode = [[PlaygroundContainerNode alloc] initWithIndex:index];
    containerCellNode.delegate = self;
    return containerCellNode;
  };
}

// [ASViewController] Override this method to provide a custom size range to the backing node.
// Neccessary to allow the user to stretch / shrink the size of playground container.
- (ASSizeRange)nodeConstrainedSize
{
  if (CGSizeEqualToSize(_sizeRange.max, CGSizeZero)) {
    return [super nodeConstrainedSize];
  }
  return _sizeRange;
}

- (ASSizeRange)pagerNode:(ASPagerNode *)pagerNode constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  if (CGSizeEqualToSize(_sizeRange.max, CGSizeZero)) {
    return [super nodeConstrainedSize];
  }
  return _sizeRange;
}

#pragma mark - PlaygroundContainerNodeDelegate

- (void)relayoutWithSize:(ASSizeRange)size
{
//  NSLog(@"DELEGATE constrainedSize = %@", NSStringFromCGSize(size.max));
  _sizeRange = size;
  [self.view setNeedsLayout];
  [_pagerNode reloadData];
}

#pragma mark - ASLayoutableInspectorNodeDelegate

- (void)toggleVisualization:(BOOL)toggle
{
  NSLog(@"shouldVisualizeLayoutSpecs:%d", toggle);
  [self.node setShouldVisualizeLayoutSpecs:toggle];
}

@end

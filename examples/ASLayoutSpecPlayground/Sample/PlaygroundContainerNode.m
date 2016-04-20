//
//  PlaygroundContainerNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "PlaygroundContainerNode.h"
#import "PlaygroundNode.h"
#import "ASLayoutableInspectorNode.h"  // FIXME: move to ASLayoutSpecDebug
#import "AsyncDisplayKit+Debug.h"

#define RESIZE_HANDLE_SIZE 30

@implementation PlaygroundContainerNode
{
  PlaygroundNode *_playgroundNode;
  ASImageNode    *_resizeHandle;
  CGPoint        _resizeStartLocation;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    self.backgroundColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
    self.usesImplicitHierarchyManagement = YES;
    
    _playgroundNode = [[PlaygroundNode alloc] init];
    
    _resizeHandle                        = [[ASImageNode alloc] init];
    _resizeHandle.image                  = [UIImage imageNamed:@"resizeHandle"];
    _resizeHandle.userInteractionEnabled = YES;
    [self addSubnode:_resizeHandle];
    
    [ASLayoutableInspectorNode sharedInstance].flexBasis = ASRelativeDimensionMakeWithPercent(1.0);
    [ASLayoutableInspectorNode sharedInstance].vizNodeInsetSize = 10.0;
    
    self.shouldVisualizeLayoutSpecs = YES;
  }
  
  return self;
}

- (void)didLoad
{
  [super didLoad];
  UIPanGestureRecognizer *gr = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizePlayground:)];
  [_resizeHandle.view addGestureRecognizer:gr];
}

// manually layout _resizeHandle              // FIXME: add this to an overlayStack in layoutSpecThatFits?
- (void)layout
{
  [super layout];
  [self.view bringSubviewToFront:_resizeHandle.view];
  
  CGSize playgroundSize = _playgroundNode.calculatedLayout.size;
  CGRect rect           = CGRectZero;
  rect.size             = CGSizeMake(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE);
  rect.origin           = CGPointMake(playgroundSize.width - rect.size.width, playgroundSize.height - rect.size.height);
  _resizeHandle.frame   = rect;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _playgroundNode.flexGrow = YES;
  _playgroundNode.flexShrink = YES;

  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 10, 10, 10)
                                                child:_playgroundNode];
}

#pragma mark - Gesture Handling

- (void)resizePlayground:(UIPanGestureRecognizer *)sender
{
  if (sender.state == UIGestureRecognizerStateBegan) {
    _resizeStartLocation = [sender locationInView:sender.view];
  }
  else if (sender.state == UIGestureRecognizerStateChanged) {
    CGPoint location = [sender locationInView:sender.view];
    CGPoint translation = CGPointMake(location.x - _resizeStartLocation.x, location.y - _resizeStartLocation.y);
    [self changePlaygroundFrameWithTranslation:translation];
  }
  else if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled || sender.state == UIGestureRecognizerStateFailed) {
    _resizeStartLocation = CGPointZero;
  }
}

- (void)changePlaygroundFrameWithTranslation:(CGPoint)translation
{
  ASSizeRange constrainedSize = self.constrainedSizeForCalculatedLayout;
  
  constrainedSize.max.width  = MAX(0, constrainedSize.max.width  + translation.x);
  constrainedSize.max.height = MAX(0, constrainedSize.max.height + translation.y);
  
  [self.delegate relayoutWithSize:constrainedSize];
}

@end

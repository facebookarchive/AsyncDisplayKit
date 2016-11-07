//
//  PlaygroundContainerNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "PlaygroundContainerNode.h"
#import "LayoutExampleNodes.h"
#import "PhotoPostNode.h"
#import <AsyncDisplayKit/ASLayoutElementInspectorNode.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>

#define RESIZE_HANDLE_SIZE 30

@implementation PlaygroundContainerNode
{
  ASDisplayNode  *_playgroundNode;
  ASImageNode    *_resizeHandle;
  CGPoint        _resizeStartLocation;
}

#pragma mark - Lifecycle

+ (NSUInteger)containerNodeCount
{
  return 5;
}

+ (ASDisplayNode *)nodeForIndex:(NSUInteger)index
{
  switch (index) {
    case 0: return [[HorizontalStackWithSpacer alloc] init];
    case 1: return [[PhotoWithInsetTextOverlay alloc] init];
    case 2: return [[PhotoWithOutsetIconOverlay alloc] init];
    case 3: return [[FlexibleSeparatorSurroundingContent alloc] init];
    case 4: return [[PhotoPostNode alloc] initWithIndex:0];
    default: return [[PhotoPostNode alloc] initWithIndex:1];
  }
}

- (instancetype)initWithIndex:(NSUInteger)index
{
  self = [super init];
  
  if (self) {
    self.backgroundColor = [UIColor whiteColor]; //[UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
    self.automaticallyManagesSubnodes = YES;
    
    _playgroundNode = [[self class] nodeForIndex:index];
    
    _resizeHandle                        = [[ASImageNode alloc] init];
    _resizeHandle.image                  = [UIImage imageNamed:@"resizeHandle"];
    _resizeHandle.userInteractionEnabled = YES;
//    [self addSubnode:_resizeHandle];
    
    [ASLayoutElementInspectorNode sharedInstance].style.flexBasis = ASDimensionMakeWithFraction(1.0);
    [ASLayoutElementInspectorNode sharedInstance].vizNodeInsetSize = 10.0;

    self.shouldVisualizeLayoutSpecs = NO;
    self.shouldCacheLayoutSpec = NO;
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
  _playgroundNode.style.flexGrow = 1.0;
  _playgroundNode.style.flexShrink = 1.0;

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

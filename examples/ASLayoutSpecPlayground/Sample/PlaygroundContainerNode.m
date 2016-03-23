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

@implementation PlaygroundContainerNode
{
  PlaygroundNode *_playgroundNode;
  ASDisplayNode  *_resizeHandle;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    
    self.backgroundColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
    self.usesImplicitHierarchyManagement = YES;
    
    [ASLayoutableInspectorNode sharedInstance].flexBasis = ASRelativeDimensionMakeWithPercent(1.0);
    
    _playgroundNode = [[PlaygroundNode alloc] init];
    
    _resizeHandle = [[ASDisplayNode alloc] init];
    _resizeHandle.backgroundColor = [UIColor greenColor];
    [self.view addSubnode:_resizeHandle];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(resizePlayground:)];
    lpgr.minimumPressDuration = 0.0;
    lpgr.allowableMovement = CGFLOAT_MAX;
    [_resizeHandle.view addGestureRecognizer:lpgr];
    
    [self shouldVisualizeLayoutSpecs:YES];

  }
  
  return self;
}

#define RESIZE_HANDLE_SIZE 10
- (void)layout
{
  [super layout];
  [self.view bringSubviewToFront:_resizeHandle.view];
  
  CGSize playgroundSize = _playgroundNode.calculatedLayout.size;   // FIXME:this might be a bug with implicit heirarchy - frame isn't set yet
//  _playgroundNode.frame = CGRectMake(300, 200, playgroundSize.width, playgroundSize.height);
//  
  
  CGRect rect = CGRectZero;
  rect.size = CGSizeMake(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE);   // FIXME: make this an overlay stack?
  rect.origin = CGPointMake(playgroundSize.width - rect.size.width, playgroundSize.height - rect.size.height);
  _resizeHandle.frame = rect;
}

//// use manual ASLayout
//- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize  // this might be a bug: implicit adding doesn't appear to work
//{
//  ASLayout *playgroundSubLayout = [_playgroundNode measureWithSizeRange:constrainedSize];
//  playgroundSubLayout.position = CGPointZero;
//  return [ASLayout layoutWithLayoutableObject:self size:constrainedSize.max position:CGPointZero sublayouts:@[playgroundSubLayout] flattened:NO];
//}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  UIEdgeInsets insets = UIEdgeInsetsMake(200, 100, 200, 100);
  ASInsetLayoutSpec *insetLayoutSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_playgroundNode];
  
  return insetLayoutSpec;
}

- (void)resizePlayground:(UIGestureRecognizer *)sender
{
  NSLog(@"RESIZE PLAYGROUND");
  
  CGPoint firstLocation;
  
  if (sender.state == UIGestureRecognizerStateBegan) {
    firstLocation = [sender locationInView:sender.view];
  }
  else if (sender.state == UIGestureRecognizerStateChanged) {
    CGPoint location = [sender locationInView:sender.view];
    CGPoint translation = CGPointMake(location.x - firstLocation.x, location.y - firstLocation.y);
    [self changePlaygroundFrameWithTranslation:translation];
  }
  else if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled || sender.state == UIGestureRecognizerStateFailed) {
    firstLocation = CGPointZero;
  }
}

- (void)changePlaygroundFrameWithTranslation:(CGPoint)translation
{
  CGRect newFrame = _playgroundNode.frame;
  
  newFrame.size.width  += translation.x;
  newFrame.size.height += translation.y;
  
  NSLog(@"%@", NSStringFromCGRect(newFrame));
  
  [_playgroundNode setSizeRange:ASRelativeSizeRangeMakeWithExactCGSize(newFrame.size)];
  [self setNeedsLayout];
}

// use manual calculateLayoutThatFits

// create constrainedSize with drag resizable box

@end

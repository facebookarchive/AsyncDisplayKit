//
//  ViewController.m
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#pragma mark - TransitionNode

#define USE_CUSTOM_LAYOUT_TRANSITION 0

@interface TransitionNode : ASDisplayNode
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) ASButtonNode *buttonNode;
@property (nonatomic, strong) ASTextNode *textNodeOne;
@property (nonatomic, strong) ASTextNode *textNodeTwo;
@end

@implementation TransitionNode


#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  if (self == nil) { return self; }
  
  self.automaticallyManagesSubnodes = YES;
  
  // Define the layout transition duration for the default transition
  self.defaultLayoutTransitionDuration = 1.0;
  
  _enabled = NO;
  
  // Setup text nodes
  _textNodeOne = [[ASTextNode alloc] init];
  _textNodeOne.attributedText = [[NSAttributedString  alloc] initWithString:@"Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled"];
  
  _textNodeTwo = [[ASTextNode alloc] init];
  _textNodeTwo.attributedText = [[NSAttributedString  alloc] initWithString:@"It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English."];
  ASSetDebugNames(_textNodeOne, _textNodeTwo);
  
  // Setup button
  NSString *buttonTitle = @"Start Layout Transition";
  UIFont *buttonFont = [UIFont systemFontOfSize:16.0];
  UIColor *buttonColor = [UIColor blueColor];
  
  _buttonNode = [[ASButtonNode alloc] init];
  [_buttonNode setTitle:buttonTitle withFont:buttonFont withColor:buttonColor forState:UIControlStateNormal];
  [_buttonNode setTitle:buttonTitle withFont:buttonFont withColor:[buttonColor colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
  
  
  // Some debug colors
  _textNodeOne.backgroundColor = [UIColor orangeColor];
  _textNodeTwo.backgroundColor = [UIColor greenColor];
  
  
  return self;
}

- (void)didLoad
{
  [super didLoad];
  
  [self.buttonNode addTarget:self action:@selector(buttonPressed:) forControlEvents:ASControlNodeEventTouchUpInside];
}

#pragma mark - Actions

- (void)buttonPressed:(id)sender
{
  self.enabled = !self.enabled;
  [self transitionLayoutWithAnimation:YES shouldMeasureAsync:NO measurementCompletion:nil];
}


#pragma mark - Layout

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASTextNode *nextTextNode = self.enabled ? self.textNodeTwo : self.textNodeOne;
  nextTextNode.style.flexGrow = 1.0;
  nextTextNode.style.flexShrink = 1.0;
  
  ASStackLayoutSpec *horizontalStackLayout = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStackLayout.children = @[nextTextNode];
  
  self.buttonNode.style.alignSelf = ASStackLayoutAlignSelfCenter;
  
  ASStackLayoutSpec *verticalStackLayout = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStackLayout.spacing = 10.0;
  verticalStackLayout.children = @[horizontalStackLayout, self.buttonNode];
  
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0) child:verticalStackLayout];
}


#pragma mark - Transition

#if USE_CUSTOM_LAYOUT_TRANSITION

- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  ASDisplayNode *fromNode = [[context removedSubnodes] objectAtIndex:0];
  ASDisplayNode *toNode = [[context insertedSubnodes] objectAtIndex:0];
  
  ASButtonNode *buttonNode = nil;
  for (ASDisplayNode *node in [context subnodesForKey:ASTransitionContextToLayoutKey]) {
    if ([node isKindOfClass:[ASButtonNode class]]) {
      buttonNode = (ASButtonNode *)node;
      break;
    }
  }
  
  CGRect toNodeFrame = [context finalFrameForNode:toNode];
  toNodeFrame.origin.x += (self.enabled ? toNodeFrame.size.width : -toNodeFrame.size.width);
  toNode.frame = toNodeFrame;
  toNode.alpha = 0.0;
  
  CGRect fromNodeFrame = fromNode.frame;
  fromNodeFrame.origin.x += (self.enabled ? -fromNodeFrame.size.width : fromNodeFrame.size.width);
  
  // We will use the same transition duration as the default transition
  [UIView animateWithDuration:self.defaultLayoutTransitionDuration animations:^{
    toNode.frame = [context finalFrameForNode:toNode];
    toNode.alpha = 1.0;
    
    fromNode.frame = fromNodeFrame;
    fromNode.alpha = 0.0;
    
    // Update frame of self
    CGSize fromSize = [context layoutForKey:ASTransitionContextFromLayoutKey].size;
    CGSize toSize = [context layoutForKey:ASTransitionContextToLayoutKey].size;
    BOOL isResized = (CGSizeEqualToSize(fromSize, toSize) == NO);
    if (isResized == YES) {
      CGPoint position = self.frame.origin;
      self.frame = CGRectMake(position.x, position.y, toSize.width, toSize.height);
    }
    
    buttonNode.frame = [context finalFrameForNode:buttonNode];
  } completion:^(BOOL finished) {
    [context completeTransition:finished];
  }];
}

#endif

@end


#pragma mark - ViewController

@interface ViewController ()
@property (nonatomic, strong) TransitionNode *transitionNode;
@end

@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _transitionNode = [TransitionNode new];
  [self.view addSubnode:_transitionNode];
  
  // Some debug colors
  _transitionNode.backgroundColor = [UIColor grayColor];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGSize size = [self.transitionNode layoutThatFits:ASSizeRangeMake(CGSizeZero, self.view.frame.size)].size;
  self.transitionNode.frame = CGRectMake(0, 20, size.width, size.height);
}

@end

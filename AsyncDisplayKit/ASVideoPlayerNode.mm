//
//  ASVideoPlayerNode.m
//  AsyncDisplayKit
//
//  Created by Erekle on 5/6/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASVideoPlayerNode.h"

static NSString * const kASVideoPlayerNodePlayButton = @"playButton";

@interface ASVideoPlayerNode()
{
  ASDN::RecursiveMutex _videoPlayerLock;
  
  NSURL *_url;
  AVAsset *_asset;
  
  ASVideoNode *_videoNode;
  
  ASDisplayNode *_controlsHolderNode;

  NSArray *_neededControls;

  NSMutableDictionary *_cachedControls;
}

@end

@implementation ASVideoPlayerNode
- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }

  [self privateInit];

  return self;
}

- (instancetype)initWithUrl:(NSURL*)url
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _url = url;
  
  [self privateInit];
  
  return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _asset = asset;

  [self privateInit];

  return self;
}

- (void)privateInit
{

  _neededControls = [self createNeededControlElementsArray];
  _cachedControls = [[NSMutableDictionary alloc] init];

  _videoNode = [[ASVideoNode alloc] init];
  _videoNode.asset = [AVAsset assetWithURL:_url];
  [self addSubnode:_videoNode];

  _controlsHolderNode = [[ASDisplayNode alloc] init];
  _controlsHolderNode.backgroundColor = [UIColor greenColor];
  [self addSubnode:_controlsHolderNode];

  [self createControls];
}

- (NSArray*)createNeededControlElementsArray
{
  //TODO:: Maybe here we will ask delegate what he needs and we force delegate to use our static strings or something like that
  return @[kASVideoPlayerNodePlayButton];
}

#pragma mark - UI
- (void)createControls
{
  for (NSString *controlType in _neededControls) {
    if ([controlType isEqualToString:kASVideoPlayerNodePlayButton]) {
      [self createPlayButton];
    }
  }
}

- (void)createPlayButton
{
  ASControlNode *playButton = [_cachedControls objectForKey:kASVideoPlayerNodePlayButton];
  if (!playButton) {
    playButton = [[ASControlNode alloc] init];
    playButton.preferredFrameSize = CGSizeMake(20.0, 20.0);
    playButton.backgroundColor  = [UIColor redColor];

    [_cachedControls setObject:playButton forKey:kASVideoPlayerNodePlayButton];
  }

  [self addSubnode:playButton];
}

#pragma mark - Layout
- (ASLayoutSpec*)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _videoNode.preferredFrameSize = constrainedSize.max;

  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;

  ASStackLayoutSpec *controlsSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                            spacing:0.0
                                                                     justifyContent:ASStackLayoutJustifyContentStart
                                                                         alignItems:ASStackLayoutAlignItemsStart
                                                                           children:[_cachedControls allValues]];

  UIEdgeInsets insets = UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);

  ASInsetLayoutSpec *controlsInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:controlsSpec];

  ASStackLayoutSpec *mainVerticalStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:0.0
                                                                          justifyContent:ASStackLayoutJustifyContentStart
                                                                              alignItems:ASStackLayoutAlignItemsStart
                                                                                children:@[spacer,controlsInsetSpec]];

  
  ASOverlayLayoutSpec *overlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_videoNode overlay:mainVerticalStack];

  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[overlaySpec]];
}

@end

//
//  ASVideoPlayerNode.m
//  AsyncDisplayKit
//
//  Created by Erekle on 5/6/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASVideoPlayerNode.h"

static void *ASVideoPlayerNodeContext = &ASVideoPlayerNodeContext;

@interface ASVideoPlayerNode() <ASVideoNodeDelegate>
{
  ASDN::RecursiveMutex _videoPlayerLock;
  
  NSURL *_url;
  AVAsset *_asset;
  
  ASVideoNode *_videoNode;
  
  ASDisplayNode *_controlsHolderNode;

  NSArray *_neededControls;

  NSMutableArray *_cachedControls;

  ASControlNode *_playbackButtonNode;
  ASTextNode  *_elapsedTextNode;
  ASTextNode  *_durationTextNode;
  ASDisplayNode *_scrubberNode;
  ASStackLayoutSpec *_controlFlexGrowSpacerSpec;

  BOOL _isSeeking;
  CGFloat _duration;

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
  _asset = [AVAsset assetWithURL:_url];
  
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
  _cachedControls = [[NSMutableArray alloc] init];

  _videoNode = [[ASVideoNode alloc] init];
  _videoNode.asset = _asset;
  _videoNode.delegate = self;
  [self addSubnode:_videoNode];

  _controlsHolderNode = [[ASDisplayNode alloc] init];
  _controlsHolderNode.backgroundColor = [UIColor greenColor];
  [self addSubnode:_controlsHolderNode];

  [self createControls];

  [self addObservers];
}

- (NSArray*)createNeededControlElementsArray
{
  //TODO:: Maybe here we will ask delegate what he needs and we force delegate to use our static strings or something like that
  return @[ @(ASVideoPlayerNodeControlTypePlaybackButton),
            @(ASVideoPlayerNodeControlTypeElapsedText),
            @(ASVideoPlayerNodeControlTypeScrubber),
            @(ASVideoPlayerNodeControlTypeFlexGrowSpacer),
            @(ASVideoPlayerNodeControlTypeDurationText) ];
}

- (void)addObservers
{

}

- (void)removeObservers
{

}

#pragma mark - UI
- (void)createControls
{
  ASDN::MutexLocker l(_videoPlayerLock);

  for (int i = 0; i < _neededControls.count; i++) {
    ASVideoPlayerNodeControlType type = (ASVideoPlayerNodeControlType)[[_neededControls objectAtIndex:i] integerValue];
    switch (type) {
      case ASVideoPlayerNodeControlTypePlaybackButton:
        [self createPlaybackButton];
        break;
      case ASVideoPlayerNodeControlTypeElapsedText:
        [self createElapsedTextField];
        break;
      case ASVideoPlayerNodeControlTypeDurationText:
        [self createDurationTextField];
        break;
      case ASVideoPlayerNodeControlTypeScrubber:
        [self createScrubber];
        break;
      case ASVideoPlayerNodeControlTypeFlexGrowSpacer:
        [self createControlFlexGrowSpacer];
        break;
      default:
        break;
    }
  }
}

- (void)removeControls
{
  [_cachedControls enumerateObjectsUsingBlock:^(ASDisplayNode   *_Nonnull node, NSUInteger idx, BOOL * _Nonnull stop) {
    [node.view removeFromSuperview];
    [node removeFromSupernode];
    node = nil;
    NSLog(@"%@",_playbackButtonNode);
  }];
}

- (void)createPlaybackButton
{
  if (_playbackButtonNode == nil) {
    _playbackButtonNode = [[ASControlNode alloc] init];
    _playbackButtonNode.preferredFrameSize = CGSizeMake(20.0, 20.0);
    _playbackButtonNode.backgroundColor  = [UIColor redColor];
    [_playbackButtonNode addTarget:self action:@selector(playbackButtonTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
    [_cachedControls addObject:_playbackButtonNode];
  }

  [self addSubnode:_playbackButtonNode];
}

- (void)createElapsedTextField
{
  if (_elapsedTextNode == nil) {
    _elapsedTextNode = [[ASTextNode alloc] init];
    _elapsedTextNode.attributedString = [self timeLabelAttributedStringForString:@"00:00"];

    [_cachedControls addObject:_elapsedTextNode];
  }
  [self addSubnode:_elapsedTextNode];
}

- (void)createDurationTextField
{
  if (_durationTextNode == nil) {
    _durationTextNode = [[ASTextNode alloc] init];
    _durationTextNode.attributedString = [self timeLabelAttributedStringForString:@"00:00"];

    [_cachedControls addObject:_durationTextNode];
  }
  [self addSubnode:_durationTextNode];
}

- (void)createScrubber
{
  if (_scrubberNode == nil) {
    _scrubberNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull{
      UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
      slider.minimumValue = 0.0;
      slider.maximumValue = 1.0;

      [slider addTarget:self action:@selector(beganSeek) forControlEvents:UIControlEventTouchDown];
      [slider addTarget:self action:@selector(endedSeek) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
      [slider addTarget:self action:@selector(changedSeekValue:) forControlEvents:UIControlEventValueChanged];

      return slider;
    }];

    _scrubberNode.flexShrink = YES;

    [_cachedControls addObject:_scrubberNode];
  }

  [self addSubnode:_scrubberNode];
}

- (void)createControlFlexGrowSpacer
{
  if (_controlFlexGrowSpacerSpec == nil) {
    _controlFlexGrowSpacerSpec = [[ASStackLayoutSpec alloc] init];
    _controlFlexGrowSpacerSpec.flexGrow = YES;
  }

  [_cachedControls addObject:_controlFlexGrowSpacerSpec];
}

- (void)updateDurationTimeLabel
{
  NSString *formatedDuration = [self timeFormatted:round(_duration)];
  _durationTextNode.attributedString = [self timeLabelAttributedStringForString:formatedDuration];
}

- (void)updateElapsedTimeLabel:(NSTimeInterval)seconds
{
  NSString *formatedDuration = [self timeFormatted:round(seconds)];
  _elapsedTextNode.attributedString = [self timeLabelAttributedStringForString:formatedDuration];
}

- (NSAttributedString*)timeLabelAttributedStringForString:(NSString*)string
{
  //TODO:: maybe we can ask delegate for this options too
  NSDictionary *options = @{
                            NSFontAttributeName : [UIFont systemFontOfSize:12.0],
                            NSForegroundColorAttributeName: [UIColor whiteColor]
                            };

  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:options];

  return attributedString;
}

#pragma mark - ASVideoNodeDelegate
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toSate
{
  if (toSate == ASVideoNodePlayerStateReadyToPlay) {
    _duration = CMTimeGetSeconds(_videoNode.currentItem.duration);
    [self updateDurationTimeLabel];
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToSecond:(NSTimeInterval)second
{
  if(_isSeeking){
    return;
  }

  [self updateElapsedTimeLabel:second];
  [(UISlider*)_scrubberNode.view setValue:(second/_duration) animated:NO];
}

- (void)videoPlaybackDidFinish:(ASVideoNode *)videoNode
{
  //[self removeControls];
}

#pragma mark - Actions
- (void)playbackButtonTapped:(ASControlNode*)node
{
  if (_videoNode.playerState == ASVideoNodePlayerStatePlaying) {
    [_videoNode pause];
    _playbackButtonNode.backgroundColor = [UIColor greenColor];
  } else {
    [_videoNode play];
    _playbackButtonNode.backgroundColor = [UIColor redColor];
  }
}

- (void)beganSeek
{
  _isSeeking = YES;
}

- (void)endedSeek
{
  _isSeeking = NO;
}

- (void)changedSeekValue:(UISlider*)slider
{
  CGFloat percentage = slider.value * 100;
  [self seekToTime:percentage];
}

-(void)seekToTime:(CGFloat)percentComplete
{
  CGFloat seconds = (_duration * percentComplete) / 100;

  [self updateElapsedTimeLabel:seconds];
  [_videoNode.player seekToTime:CMTimeMakeWithSeconds(seconds, _videoNode.periodicTimeObserverTimescale)];

  if (_videoNode.playerState != ASVideoNodePlayerStatePlaying) {
    [_videoNode play];
  }
}


#pragma mark - Layout
- (ASLayoutSpec*)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _videoNode.preferredFrameSize = constrainedSize.max;
  _scrubberNode.preferredFrameSize = CGSizeMake(constrainedSize.max.width, 44.0);

  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;

  ASStackLayoutSpec *controlbarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                            spacing:10.0
                                                                     justifyContent:ASStackLayoutJustifyContentStart
                                                                         alignItems:ASStackLayoutAlignItemsCenter
                                                                           children:_cachedControls];
  controlbarSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  UIEdgeInsets insets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);

  ASInsetLayoutSpec *controlbarInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:controlbarSpec];

  controlbarInsetSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  ASStackLayoutSpec *mainVerticalStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:0.0
                                                                          justifyContent:ASStackLayoutJustifyContentStart
                                                                              alignItems:ASStackLayoutAlignItemsStart
                                                                                children:@[spacer,controlbarInsetSpec]];

  
  ASOverlayLayoutSpec *overlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_videoNode overlay:mainVerticalStack];

  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[overlaySpec]];
}

#pragma mark - Helpers
- (NSString *)timeFormatted:(int)totalSeconds
{

  int seconds = totalSeconds % 60;
  int minutes = (totalSeconds / 60) % 60;

  return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
}

#pragma mark - Lifecycle

- (void)dealloc
{
  [self removeObservers];
}

@end

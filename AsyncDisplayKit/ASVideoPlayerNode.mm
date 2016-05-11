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

  __weak id<ASVideoPlayerNodeDelegate> _delegate;

  struct {
    unsigned int delegateNeededControls:1;
    unsigned int delegateScrubberMaximumTrackTintColor:1;
    unsigned int delegateScrubberMinimumTrackTintColor:1;
    unsigned int delegateScrubberThumbTintColor:1;
    unsigned int delegateScrubberThumbImage:1;
    unsigned int delegateTimeLabelAttributes:1;
    unsigned int delegateLayoutSpecForControls:1;
  } _delegateFlags;
  
  NSURL *_url;
  AVAsset *_asset;
  
  ASVideoNode *_videoNode;
  
  ASDisplayNode *_controlsHolderNode;

  NSArray *_neededControls;

  NSMutableDictionary *_cachedControls;

  ASControlNode *_playbackButtonNode;
  ASTextNode  *_elapsedTextNode;
  ASTextNode  *_durationTextNode;
  ASDisplayNode *_scrubberNode;
  ASStackLayoutSpec *_controlFlexGrowSpacerSpec;

  BOOL _isSeeking;
  CMTime _duration;

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

  _cachedControls = [[NSMutableDictionary alloc] init];

  _videoNode = [[ASVideoNode alloc] init];
  _videoNode.asset = _asset;
  _videoNode.delegate = self;
  [self addSubnode:_videoNode];

  _controlsHolderNode = [[ASDisplayNode alloc] init];
  _controlsHolderNode.backgroundColor = [UIColor greenColor];
  [self addSubnode:_controlsHolderNode];

  [self addObservers];
}

- (void)didLoad
{
  [super didLoad];
  {
    ASDN::MutexLocker l(_videoPlayerLock);
    [self createControls];
  }
}

- (NSArray*)createControlElementArray
{
  if (_delegateFlags.delegateNeededControls) {
    return [_delegate videoPlayerNodeNeededControls:self];
  }

  return @[ @(ASVideoPlayerNodeControlTypePlaybackButton),
            @(ASVideoPlayerNodeControlTypeElapsedText),
            @(ASVideoPlayerNodeControlTypeScrubber),
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

  if (_neededControls == nil) {
    _neededControls = [self createControlElementArray];
  }

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
//  [_cachedControls enumerateObjectsUsingBlock:^(ASDisplayNode   *_Nonnull node, NSUInteger idx, BOOL * _Nonnull stop) {
//    [node.view removeFromSuperview];
//    [node removeFromSupernode];
//    node = nil;
//    NSLog(@"%@",_playbackButtonNode);
//  }];
}

- (void)createPlaybackButton
{
  if (_playbackButtonNode == nil) {
    _playbackButtonNode = [[ASControlNode alloc] init];
    _playbackButtonNode.preferredFrameSize = CGSizeMake(20.0, 20.0);
    _playbackButtonNode.backgroundColor  = [UIColor redColor];
    [_playbackButtonNode addTarget:self action:@selector(playbackButtonTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
    [_cachedControls setObject:_playbackButtonNode forKey:@(ASVideoPlayerNodeControlTypePlaybackButton)];
  }

  [self addSubnode:_playbackButtonNode];
}

- (void)createElapsedTextField
{
  if (_elapsedTextNode == nil) {
    _elapsedTextNode = [[ASTextNode alloc] init];
    _elapsedTextNode.attributedString = [self timeLabelAttributedStringForString:@"00:00" forControlType:ASVideoPlayerNodeControlTypeElapsedText];

    [_cachedControls setObject:_elapsedTextNode forKey:@(ASVideoPlayerNodeControlTypeElapsedText)];
  }
  [self addSubnode:_elapsedTextNode];
}

- (void)createDurationTextField
{
  if (_durationTextNode == nil) {
    _durationTextNode = [[ASTextNode alloc] init];
    _durationTextNode.attributedString = [self timeLabelAttributedStringForString:@"00:00" forControlType:ASVideoPlayerNodeControlTypeDurationText];

    [_cachedControls setObject:_durationTextNode forKey:@(ASVideoPlayerNodeControlTypeDurationText)];
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

      if (_delegateFlags.delegateScrubberMinimumTrackTintColor) {
        slider.minimumTrackTintColor  = [_delegate videoPlayerNodeScrubberMinimumTrackTint:self];
      }

      if (_delegateFlags.delegateScrubberMaximumTrackTintColor) {
        slider.maximumTrackTintColor  = [_delegate videoPlayerNodeScrubberMaximumTrackTint:self];
      }

      if (_delegateFlags.delegateScrubberThumbTintColor) {
        slider.thumbTintColor  = [_delegate videoPlayerNodeScrubberThumbTint:self];
      }

      if (_delegateFlags.delegateScrubberThumbImage) {
        UIImage *thumbImage = [_delegate videoPlayerNodeScrubberThumbImage:self];
        [slider setThumbImage:thumbImage forState:UIControlStateNormal];
      }


      [slider addTarget:self action:@selector(beganSeek) forControlEvents:UIControlEventTouchDown];
      [slider addTarget:self action:@selector(endedSeek) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
      [slider addTarget:self action:@selector(changedSeekValue:) forControlEvents:UIControlEventValueChanged];

      return slider;
    }];

    _scrubberNode.flexShrink = YES;

    [_cachedControls setObject:_scrubberNode forKey:@(ASVideoPlayerNodeControlTypeScrubber)];
  }

  [self addSubnode:_scrubberNode];
}

- (void)createControlFlexGrowSpacer
{
  if (_controlFlexGrowSpacerSpec == nil) {
    _controlFlexGrowSpacerSpec = [[ASStackLayoutSpec alloc] init];
    _controlFlexGrowSpacerSpec.flexGrow = YES;
  }

  [_cachedControls setObject:_controlFlexGrowSpacerSpec forKey:@(ASVideoPlayerNodeControlTypeFlexGrowSpacer)];
}

- (void)updateDurationTimeLabel
{
  NSString *formatedDuration = [self timeStringForCMTime:_duration];
  _durationTextNode.attributedString = [self timeLabelAttributedStringForString:formatedDuration forControlType:ASVideoPlayerNodeControlTypeDurationText];
}

- (void)updateElapsedTimeLabel:(NSTimeInterval)seconds
{
  NSString *formatedDuration = [self timeStringForCMTime:CMTimeMakeWithSeconds( seconds, _videoNode.periodicTimeObserverTimescale )];
  _elapsedTextNode.attributedString = [self timeLabelAttributedStringForString:formatedDuration forControlType:ASVideoPlayerNodeControlTypeElapsedText];
}

- (NSAttributedString*)timeLabelAttributedStringForString:(NSString*)string forControlType:(ASVideoPlayerNodeControlType)controlType
{
  NSDictionary *options;
  if (_delegateFlags.delegateTimeLabelAttributes) {
    options = [_delegate videoPlayerNodeTimeLabelAttributes:self timeLabelType:controlType];
  } else {
    options = @{
                NSFontAttributeName : [UIFont systemFontOfSize:12.0],
                NSForegroundColorAttributeName: [UIColor whiteColor]
                };
  }


  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:options];

  return attributedString;
}

#pragma mark - ASVideoNodeDelegate
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toSate
{
  if (toSate == ASVideoNodePlayerStateReadyToPlay) {
    _duration = _videoNode.currentItem.duration;
    [self updateDurationTimeLabel];
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToSecond:(NSTimeInterval)second
{
  if(_isSeeking){
    return;
  }

  [self updateElapsedTimeLabel:second];
  [(UISlider*)_scrubberNode.view setValue:(second/ CMTimeGetSeconds(_duration) ) animated:NO];
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
  CGFloat seconds = ( CMTimeGetSeconds(_duration) * percentComplete ) / 100;

  [self updateElapsedTimeLabel:seconds];
  [_videoNode.player seekToTime:CMTimeMakeWithSeconds(seconds, _videoNode.periodicTimeObserverTimescale)];

  if (_videoNode.playerState != ASVideoNodePlayerStatePlaying) {
    [_videoNode play];
  }
}

- (NSArray *)controlsForLayoutSpec
{
  NSMutableArray *controls = [[NSMutableArray alloc] initWithCapacity:_cachedControls.count];

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypePlaybackButton) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypePlaybackButton) ]];
  }

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeElapsedText) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeElapsedText) ]];
  }

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeScrubber) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeScrubber) ]];
  }

  if (_cachedControls[ @(ASVideoPlayerNodeControlTypeDurationText) ]) {
    [controls addObject:_cachedControls[ @(ASVideoPlayerNodeControlTypeDurationText) ]];
  }

  return controls;
}

#pragma mark - Layout
- (ASLayoutSpec*)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _videoNode.preferredFrameSize = constrainedSize.max;

  ASLayoutSpec *layoutSpec;

  if (_delegateFlags.delegateLayoutSpecForControls) {
    layoutSpec = [_delegate videoPlayerNodeLayoutSpec:self forControls:_cachedControls forConstrainedSize:constrainedSize];
  } else {
    layoutSpec = [self defaultLayoutSpecThatFits:constrainedSize];
  }

  ASOverlayLayoutSpec *overlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_videoNode overlay:layoutSpec];

  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[overlaySpec]];
}

- (ASLayoutSpec*)defaultLayoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _scrubberNode.preferredFrameSize = CGSizeMake(constrainedSize.max.width, 44.0);

  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;

  ASStackLayoutSpec *controlbarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                            spacing:10.0
                                                                     justifyContent:ASStackLayoutJustifyContentStart
                                                                         alignItems:ASStackLayoutAlignItemsCenter
                                                                           children: [self controlsForLayoutSpec] ];
  controlbarSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  UIEdgeInsets insets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);

  ASInsetLayoutSpec *controlbarInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:controlbarSpec];

  controlbarInsetSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  ASStackLayoutSpec *mainVerticalStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:0.0
                                                                          justifyContent:ASStackLayoutJustifyContentStart
                                                                              alignItems:ASStackLayoutAlignItemsStart
                                                                                children:@[spacer,controlbarInsetSpec]];

  return mainVerticalStack;
}

#pragma mark - Properties
- (id<ASVideoPlayerNodeDelegate>)delegate{
  return _delegate;
}

- (void)setDelegate:(id<ASVideoPlayerNodeDelegate>)delegate
{
  _delegate = delegate;
  
  if (_delegate == nil) {
    memset(&_delegateFlags, 0, sizeof(_delegateFlags));
  } else {
    _delegateFlags.delegateNeededControls = [_delegate respondsToSelector:@selector(videoPlayerNodeNeededControls:)];
    _delegateFlags.delegateScrubberMaximumTrackTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberMaximumTrackTint:)];
    _delegateFlags.delegateScrubberMinimumTrackTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberMinimumTrackTint:)];
    _delegateFlags.delegateScrubberThumbTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberThumbTint:)];
    _delegateFlags.delegateScrubberThumbImage = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberThumbImage:)];
    _delegateFlags.delegateTimeLabelAttributes = [_delegate respondsToSelector:@selector(videoPlayerNodeTimeLabelAttributes:timeLabelType:)];
    _delegateFlags.delegateLayoutSpecForControls = [_delegate respondsToSelector:@selector(videoPlayerNodeLayoutSpec:forControls:forConstrainedSize:)];
  }
}

#pragma mark - Helpers
- (NSString *)timeStringForCMTime:(CMTime)time
{
  NSUInteger dTotalSeconds = CMTimeGetSeconds(time);

  NSUInteger dHours = floor(dTotalSeconds / 3600);
  NSUInteger dMinutes = floor(dTotalSeconds % 3600 / 60);
  NSUInteger dSeconds = floor(dTotalSeconds % 3600 % 60);

  NSString *videoDurationText;
  if (dHours > 0) {
    videoDurationText = [NSString stringWithFormat:@"%i:%01i:%02i", (int)dHours, (int)dMinutes, (int)dSeconds];
  } else {
    videoDurationText = [NSString stringWithFormat:@"%01i:%02i", (int)dMinutes, (int)dSeconds];
  }
  return videoDurationText;
}

#pragma mark - Lifecycle

- (void)dealloc
{
  [self removeObservers];
}

@end

//
//  ASVideoPlayerNode.mm
//  AsyncDisplayKit
//
//  Created by Erekle on 5/6/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASVideoPlayerNode.h"
#import "ASDefaultPlaybackButton.h"
#import "ASDisplayNodeInternal.h"

static void *ASVideoPlayerNodeContext = &ASVideoPlayerNodeContext;

@interface ASVideoPlayerNode() <ASVideoNodeDelegate>
{
  __weak id<ASVideoPlayerNodeDelegate> _delegate;

  struct {
    unsigned int delegateNeededDefaultControls:1;
    unsigned int delegateCustomControls:1;
    unsigned int delegateSpinnerTintColor:1;
    unsigned int delegatePlaybackButtonTint:1;
    unsigned int delegateScrubberMaximumTrackTintColor:1;
    unsigned int delegateScrubberMinimumTrackTintColor:1;
    unsigned int delegateScrubberThumbTintColor:1;
    unsigned int delegateScrubberThumbImage:1;
    unsigned int delegateTimeLabelAttributes:1;
    unsigned int delegateTimeLabelAttributedString:1;
    unsigned int delegateLayoutSpecForControls:1;
    unsigned int delegateVideoNodeDidPlayToTime:1;
    unsigned int delegateVideoNodeWillChangeState:1;
    unsigned int delegateVideoNodeShouldChangeState:1;
    unsigned int delegateVideoNodePlaybackDidFinish:1;
    unsigned int delegateDidTapVideoPlayerNode:1;
    unsigned int delegateVideoPlayerNodeDidSetCurrentItem:1;
    unsigned int delegateVideoPlayerNodeDidStallAtTimeInterval:1;
    unsigned int delegateVideoPlayerNodeDidStartInitialLoading:1;
    unsigned int delegateVideoPlayerNodeDidFinishInitialLoading:1;
    unsigned int delegateVideoPlayerNodeDidRecoverFromStall:1;
  } _delegateFlags;
  
  NSURL *_url;
  AVAsset *_asset;
  AVVideoComposition *_videoComposition;
  AVAudioMix *_audioMix;
  
  ASVideoNode *_videoNode;

  NSArray *_neededDefaultControls;

  NSMutableDictionary *_cachedControls;

  ASDefaultPlaybackButton *_playbackButtonNode;
  ASTextNode  *_elapsedTextNode;
  ASTextNode  *_durationTextNode;
  ASDisplayNode *_scrubberNode;
  ASStackLayoutSpec *_controlFlexGrowSpacerSpec;
  ASDisplayNode *_spinnerNode;

  BOOL _loadAssetWhenNodeBecomesVisible;
  BOOL _isSeeking;
  CMTime _duration;

  BOOL _controlsDisabled;

  BOOL _shouldAutoPlay;
  BOOL _shouldAutoRepeat;
  BOOL _muted;
  int32_t _periodicTimeObserverTimescale;
  NSString *_gravity;

  BOOL _shouldAggressivelyRecoverFromStall;

  UIColor *_defaultControlsColor;
}

@end

@implementation ASVideoPlayerNode

@dynamic placeholderImageURL;

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }

  [self _init];

  return self;
}

- (instancetype)initWithUrl:(NSURL*)url
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _url = url;
  _asset = [AVAsset assetWithURL:_url];
  _loadAssetWhenNodeBecomesVisible = YES;
  
  [self _init];
  
  return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset
{
  if (!(self = [super init])) {
    return nil;
  }

  _asset = asset;
  _loadAssetWhenNodeBecomesVisible = YES;

  [self _init];

  return self;
}

-(instancetype)initWithAsset:(AVAsset *)asset videoComposition:(AVVideoComposition *)videoComposition audioMix:(AVAudioMix *)audioMix
{
  if (!(self = [super init])) {
    return nil;
  }

  _asset = asset;
  _videoComposition = videoComposition;
  _audioMix = audioMix;
  _loadAssetWhenNodeBecomesVisible = YES;

  [self _init];

  return self;
}

- (instancetype)initWithUrl:(NSURL *)url loadAssetWhenNodeBecomesVisible:(BOOL)loadAssetWhenNodeBecomesVisible
{
  if (!(self = [super init])) {
    return nil;
  }

  _url = url;
  _asset = [AVAsset assetWithURL:_url];
  _loadAssetWhenNodeBecomesVisible = loadAssetWhenNodeBecomesVisible;

  [self _init];

  return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset loadAssetWhenNodeBecomesVisible:(BOOL)loadAssetWhenNodeBecomesVisible
{
  if (!(self = [super init])) {
    return nil;
  }

  _asset = asset;
  _loadAssetWhenNodeBecomesVisible = loadAssetWhenNodeBecomesVisible;

  [self _init];

  return self;
}

-(instancetype)initWithAsset:(AVAsset *)asset videoComposition:(AVVideoComposition *)videoComposition audioMix:(AVAudioMix *)audioMix loadAssetWhenNodeBecomesVisible:(BOOL)loadAssetWhenNodeBecomesVisible
{
  if (!(self = [super init])) {
    return nil;
  }

  _asset = asset;
  _videoComposition = videoComposition;
  _audioMix = audioMix;
  _loadAssetWhenNodeBecomesVisible = loadAssetWhenNodeBecomesVisible;

  [self _init];

  return self;
}

- (void)_init
{
  _defaultControlsColor = [UIColor whiteColor];
  _cachedControls = [[NSMutableDictionary alloc] init];

  _videoNode = [[ASVideoNode alloc] init];
  _videoNode.delegate = self;
  if (_loadAssetWhenNodeBecomesVisible == NO) {
    _videoNode.asset = _asset;
    _videoNode.videoComposition = _videoComposition;
    _videoNode.audioMix = _audioMix;
  }
  [self addSubnode:_videoNode];
}

- (void)didLoad
{
  [super didLoad];
  {
    ASDN::MutexLocker l(_propertyLock);
    [self createControls];
  }
}

- (void)visibleStateDidChange:(BOOL)isVisible
{
  [super visibleStateDidChange:isVisible];

  ASDN::MutexLocker l(_propertyLock);

  if (isVisible && _loadAssetWhenNodeBecomesVisible) {
    if (_asset != _videoNode.asset) {
      _videoNode.asset = _asset;
    }
    if (_videoComposition != _videoNode.videoComposition) {
      _videoNode.videoComposition = _videoComposition;
    }
    if (_audioMix != _videoNode.audioMix) {
      _videoNode.audioMix = _audioMix;
    }
  }
}

- (NSArray *)createDefaultControlElementArray
{
  if (_delegateFlags.delegateNeededDefaultControls) {
    return [_delegate videoPlayerNodeNeededDefaultControls:self];
  }

  return @[ @(ASVideoPlayerNodeControlTypePlaybackButton),
            @(ASVideoPlayerNodeControlTypeElapsedText),
            @(ASVideoPlayerNodeControlTypeScrubber),
            @(ASVideoPlayerNodeControlTypeDurationText) ];
}

#pragma mark - UI
- (void)createControls
{
  ASDN::MutexLocker l(_propertyLock);

  if (_controlsDisabled) {
    return;
  }

  if (_neededDefaultControls == nil) {
    _neededDefaultControls = [self createDefaultControlElementArray];
  }

  if (_cachedControls == nil) {
    _cachedControls = [[NSMutableDictionary alloc] init];
  }

  for (id object in _neededDefaultControls) {
    ASVideoPlayerNodeControlType type = (ASVideoPlayerNodeControlType)[object integerValue];
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

  if (_delegateFlags.delegateCustomControls && _delegateFlags.delegateLayoutSpecForControls) {
    NSDictionary *customControls = [_delegate videoPlayerNodeCustomControls:self];
    for (id key in customControls) {
      id node = customControls[key];
      if (![node isKindOfClass:[ASDisplayNode class]]) {
        continue;
      }

      [self addSubnode:node];
      [_cachedControls setObject:node forKey:key];
    }
  }

  ASPerformBlockOnMainThread(^{
    ASDN::MutexLocker l(_propertyLock);
    [self setNeedsLayout];
  });
}

- (void)removeControls
{
  NSArray *controls = [_cachedControls allValues];
  [controls enumerateObjectsUsingBlock:^(ASDisplayNode   *_Nonnull node, NSUInteger idx, BOOL * _Nonnull stop) {
    [node removeFromSupernode];
  }];

  [self cleanCachedControls];
}

- (void)cleanCachedControls
{
  [_cachedControls removeAllObjects];

  _playbackButtonNode = nil;
  _elapsedTextNode = nil;
  _durationTextNode = nil;
  _scrubberNode = nil;
}

- (void)createPlaybackButton
{
  if (_playbackButtonNode == nil) {
    _playbackButtonNode = [[ASDefaultPlaybackButton alloc] init];
    _playbackButtonNode.preferredFrameSize = CGSizeMake(16.0, 22.0);
    if (_delegateFlags.delegatePlaybackButtonTint) {
      _playbackButtonNode.tintColor = [_delegate videoPlayerNodePlaybackButtonTint:self];
    } else {
      _playbackButtonNode.tintColor = _defaultControlsColor;
    }

    if (_videoNode.playerState == ASVideoNodePlayerStatePlaying) {
      _playbackButtonNode.buttonType = ASDefaultPlaybackButtonTypePause;
    }

    [_playbackButtonNode addTarget:self action:@selector(didTapPlaybackButton:) forControlEvents:ASControlNodeEventTouchUpInside];
    [_cachedControls setObject:_playbackButtonNode forKey:@(ASVideoPlayerNodeControlTypePlaybackButton)];
  }

  [self addSubnode:_playbackButtonNode];
}

- (void)createElapsedTextField
{
  if (_elapsedTextNode == nil) {
    _elapsedTextNode = [[ASTextNode alloc] init];
    _elapsedTextNode.attributedString = [self timeLabelAttributedStringForString:@"00:00"
                                                                  forControlType:ASVideoPlayerNodeControlTypeElapsedText];
    _elapsedTextNode.truncationMode = NSLineBreakByClipping;

    [_cachedControls setObject:_elapsedTextNode forKey:@(ASVideoPlayerNodeControlTypeElapsedText)];
  }
  [self addSubnode:_elapsedTextNode];
}

- (void)createDurationTextField
{
  if (_durationTextNode == nil) {
    _durationTextNode = [[ASTextNode alloc] init];
    _durationTextNode.attributedString = [self timeLabelAttributedStringForString:@"00:00"
                                                                   forControlType:ASVideoPlayerNodeControlTypeDurationText];
    _durationTextNode.truncationMode = NSLineBreakByClipping;

    [_cachedControls setObject:_durationTextNode forKey:@(ASVideoPlayerNodeControlTypeDurationText)];
  }
  [self addSubnode:_durationTextNode];
}

- (void)createScrubber
{
  if (_scrubberNode == nil) {
    __weak __typeof__(self) weakSelf = self;
    _scrubberNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull {
      __typeof__(self) strongSelf = weakSelf;
      
      UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
      slider.minimumValue = 0.0;
      slider.maximumValue = 1.0;

      if (_delegateFlags.delegateScrubberMinimumTrackTintColor) {
        slider.minimumTrackTintColor  = [_delegate videoPlayerNodeScrubberMinimumTrackTint:strongSelf];
      }

      if (_delegateFlags.delegateScrubberMaximumTrackTintColor) {
        slider.maximumTrackTintColor  = [_delegate videoPlayerNodeScrubberMaximumTrackTint:strongSelf];
      }

      if (_delegateFlags.delegateScrubberThumbTintColor) {
        slider.thumbTintColor  = [_delegate videoPlayerNodeScrubberThumbTint:strongSelf];
      }

      if (_delegateFlags.delegateScrubberThumbImage) {
        UIImage *thumbImage = [_delegate videoPlayerNodeScrubberThumbImage:strongSelf];
        [slider setThumbImage:thumbImage forState:UIControlStateNormal];
      }


      [slider addTarget:strongSelf action:@selector(beginSeek) forControlEvents:UIControlEventTouchDown];
      [slider addTarget:strongSelf action:@selector(endSeek) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
      [slider addTarget:strongSelf action:@selector(seekTimeDidChange:) forControlEvents:UIControlEventValueChanged];

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
  if (!_durationTextNode) {
    return;
  }
  NSString *formattedDuration = [self timeStringForCMTime:_duration forTimeLabelType:ASVideoPlayerNodeControlTypeDurationText];
  _durationTextNode.attributedString = [self timeLabelAttributedStringForString:formattedDuration forControlType:ASVideoPlayerNodeControlTypeDurationText];
}

- (void)updateElapsedTimeLabel:(NSTimeInterval)seconds
{
  if (!_elapsedTextNode) {
    return;
  }
  NSString *formatteElapsed = [self timeStringForCMTime:CMTimeMakeWithSeconds( seconds, _videoNode.periodicTimeObserverTimescale ) forTimeLabelType:ASVideoPlayerNodeControlTypeElapsedText];
  _elapsedTextNode.attributedString = [self timeLabelAttributedStringForString:formatteElapsed forControlType:ASVideoPlayerNodeControlTypeElapsedText];
}

- (NSAttributedString*)timeLabelAttributedStringForString:(NSString*)string forControlType:(ASVideoPlayerNodeControlType)controlType
{
  NSDictionary *options;
  if (_delegateFlags.delegateTimeLabelAttributes) {
    options = [_delegate videoPlayerNodeTimeLabelAttributes:self timeLabelType:controlType];
  } else {
    options = @{
                NSFontAttributeName : [UIFont systemFontOfSize:12.0],
                NSForegroundColorAttributeName: _defaultControlsColor
                };
  }


  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:options];

  return attributedString;
}

#pragma mark - ASVideoNodeDelegate
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState
{
  if (_delegateFlags.delegateVideoNodeWillChangeState) {
    [_delegate videoPlayerNode:self willChangeVideoNodeState:state toVideoNodeState:toState];
  }

  if (toState == ASVideoNodePlayerStateReadyToPlay) {
    _duration = _videoNode.currentItem.duration;
    [self updateDurationTimeLabel];
  }

  if (toState == ASVideoNodePlayerStatePlaying) {
    _playbackButtonNode.buttonType = ASDefaultPlaybackButtonTypePause;
    [self removeSpinner];
  } else if (toState != ASVideoNodePlayerStatePlaybackLikelyToKeepUpButNotPlaying && toState != ASVideoNodePlayerStateReadyToPlay) {
    _playbackButtonNode.buttonType = ASDefaultPlaybackButtonTypePlay;
  }

  if (toState == ASVideoNodePlayerStateLoading || toState == ASVideoNodePlayerStateInitialLoading) {
    [self showSpinner];
  }

  if (toState == ASVideoNodePlayerStateReadyToPlay || toState == ASVideoNodePlayerStatePaused || toState == ASVideoNodePlayerStatePlaybackLikelyToKeepUpButNotPlaying) {
    [self removeSpinner];
  }
}

- (BOOL)videoNode:(ASVideoNode *)videoNode shouldChangePlayerStateTo:(ASVideoNodePlayerState)state
{
  if (_delegateFlags.delegateVideoNodeShouldChangeState) {
    return [_delegate videoPlayerNode:self shouldChangeVideoNodeStateTo:state];
  }
  return YES;
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToTimeInterval:(NSTimeInterval)timeInterval
{
  if (_delegateFlags.delegateVideoNodeDidPlayToTime) {
    [_delegate videoPlayerNode:self didPlayToTime:_videoNode.player.currentTime];
  }

  if (_isSeeking) {
    return;
  }

  if (_elapsedTextNode) {
    [self updateElapsedTimeLabel:timeInterval];
  }

  if (_scrubberNode) {
    [(UISlider*)_scrubberNode.view setValue:( timeInterval / CMTimeGetSeconds(_duration) ) animated:NO];
  }
}

- (void)videoDidPlayToEnd:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoNodePlaybackDidFinish) {
    [_delegate videoPlayerNodeDidPlayToEnd:self];
  }
}

- (void)didTapVideoNode:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateDidTapVideoPlayerNode) {
    [_delegate didTapVideoPlayerNode:self];
  } else {
    [self togglePlayPause];
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didSetCurrentItem:(AVPlayerItem *)currentItem
{
  if (_delegateFlags.delegateVideoPlayerNodeDidSetCurrentItem) {
    [_delegate videoPlayerNode:self didSetCurrentItem:currentItem];
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didStallAtTimeInterval:(NSTimeInterval)timeInterval
{
  if (_delegateFlags.delegateVideoPlayerNodeDidStallAtTimeInterval) {
    [_delegate videoPlayerNode:self didStallAtTimeInterval:timeInterval];
  }
}

- (void)videoNodeDidStartInitialLoading:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoPlayerNodeDidStartInitialLoading) {
    [_delegate videoPlayerNodeDidStartInitialLoading:self];
  }
}

- (void)videoNodeDidFinishInitialLoading:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoPlayerNodeDidFinishInitialLoading) {
    [_delegate videoPlayerNodeDidFinishInitialLoading:self];
  }
}

- (void)videoNodeDidRecoverFromStall:(ASVideoNode *)videoNode
{
  if (_delegateFlags.delegateVideoPlayerNodeDidRecoverFromStall) {
    [_delegate videoPlayerNodeDidRecoverFromStall:self];
  }
}

#pragma mark - Actions
- (void)togglePlayPause
{
  if (_videoNode.playerState == ASVideoNodePlayerStatePlaying) {
    [_videoNode pause];
  } else {
    [_videoNode play];
  }
}

- (void)showSpinner
{
  ASDN::MutexLocker l(_propertyLock);

  if (!_spinnerNode) {
  
    __weak __typeof__(self) weakSelf = self;
    _spinnerNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
      __typeof__(self) strongSelf = weakSelf;
      UIActivityIndicatorView *spinnnerView = [[UIActivityIndicatorView alloc] init];
      spinnnerView.backgroundColor = [UIColor clearColor];

      if (_delegateFlags.delegateSpinnerTintColor) {
        spinnnerView.color = [_delegate videoPlayerNodeSpinnerTint:strongSelf];
      } else {
        spinnnerView.color = _defaultControlsColor;
      }
      
      return spinnnerView;
    }];
    _spinnerNode.preferredFrameSize = CGSizeMake(44.0, 44.0);

    [self addSubnode:_spinnerNode];
    [self setNeedsLayout];
  }
  [(UIActivityIndicatorView *)_spinnerNode.view startAnimating];
}

- (void)removeSpinner
{
  ASDN::MutexLocker l(_propertyLock);

  if (!_spinnerNode) {
    return;
  }
  [_spinnerNode removeFromSupernode];
  _spinnerNode = nil;
}

- (void)didTapPlaybackButton:(ASControlNode*)node
{
  [self togglePlayPause];
}

- (void)beginSeek
{
  _isSeeking = YES;
}

- (void)endSeek
{
  _isSeeking = NO;
}

- (void)seekTimeDidChange:(UISlider*)slider
{
  CGFloat percentage = slider.value * 100;
  [self seekToTime:percentage];
}

#pragma mark - Public API
- (void)seekToTime:(CGFloat)percentComplete
{
  CGFloat seconds = ( CMTimeGetSeconds(_duration) * percentComplete ) / 100;

  [self updateElapsedTimeLabel:seconds];
  [_videoNode.player seekToTime:CMTimeMakeWithSeconds(seconds, _videoNode.periodicTimeObserverTimescale)];

  if (_videoNode.playerState != ASVideoNodePlayerStatePlaying) {
    [self togglePlayPause];
  }
}

- (void)play
{
  [_videoNode play];
}

- (void)pause
{
  [_videoNode pause];
}

- (BOOL)isPlaying
{
  return [_videoNode isPlaying];
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
  CGSize maxSize = constrainedSize.max;
  if (!CGSizeEqualToSize(self.preferredFrameSize, CGSizeZero)) {
    maxSize = self.preferredFrameSize;
  }

  // Prevent crashes through if infinite width or height
  if (isinf(maxSize.width) || isinf(maxSize.height)) {
    ASDisplayNodeAssert(NO, @"Infinite width or height in ASVideoPlayerNode");
    maxSize = CGSizeZero;
  }
  _videoNode.preferredFrameSize = maxSize;

  ASLayoutSpec *layoutSpec;

  if (_delegateFlags.delegateLayoutSpecForControls) {
    layoutSpec = [_delegate videoPlayerNodeLayoutSpec:self forControls:_cachedControls forMaximumSize:maxSize];
  } else {
    layoutSpec = [self defaultLayoutSpecThatFits:maxSize];
  }

  NSMutableArray *children = [[NSMutableArray alloc] init];

  if (_spinnerNode) {
    ASCenterLayoutSpec *centerLayoutSpec = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionDefault child:_spinnerNode];
    centerLayoutSpec.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(maxSize);
    [children addObject:centerLayoutSpec];
  }

  ASOverlayLayoutSpec *overlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_videoNode overlay:layoutSpec];
  overlaySpec.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(maxSize);

  [children addObject:overlaySpec];

  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:children];
}

- (ASLayoutSpec*)defaultLayoutSpecThatFits:(CGSize)maxSize
{
  _scrubberNode.preferredFrameSize = CGSizeMake(maxSize.width, 44.0);

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
- (id<ASVideoPlayerNodeDelegate>)delegate
{
  return _delegate;
}

- (void)setDelegate:(id<ASVideoPlayerNodeDelegate>)delegate
{
  if (delegate == _delegate) {
    return;
  }

  _delegate = delegate;
  
  if (_delegate == nil) {
    memset(&_delegateFlags, 0, sizeof(_delegateFlags));
  } else {
    _delegateFlags.delegateNeededDefaultControls = [_delegate respondsToSelector:@selector(videoPlayerNodeNeededDefaultControls:)];
    _delegateFlags.delegateCustomControls = [_delegate respondsToSelector:@selector(videoPlayerNodeCustomControls:)];
    _delegateFlags.delegateSpinnerTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeSpinnerTint:)];
    _delegateFlags.delegateScrubberMaximumTrackTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberMaximumTrackTint:)];
    _delegateFlags.delegateScrubberMinimumTrackTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberMinimumTrackTint:)];
    _delegateFlags.delegateScrubberThumbTintColor = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberThumbTint:)];
    _delegateFlags.delegateScrubberThumbImage = [_delegate respondsToSelector:@selector(videoPlayerNodeScrubberThumbImage:)];
    _delegateFlags.delegateTimeLabelAttributes = [_delegate respondsToSelector:@selector(videoPlayerNodeTimeLabelAttributes:timeLabelType:)];
    _delegateFlags.delegateLayoutSpecForControls = [_delegate respondsToSelector:@selector(videoPlayerNodeLayoutSpec:forControls:forMaximumSize:)];
    _delegateFlags.delegateVideoNodeDidPlayToTime = [_delegate respondsToSelector:@selector(videoPlayerNode:didPlayToTime:)];
    _delegateFlags.delegateVideoNodeWillChangeState = [_delegate respondsToSelector:@selector(videoPlayerNode:willChangeVideoNodeState:toVideoNodeState:)];
    _delegateFlags.delegateVideoNodePlaybackDidFinish = [_delegate respondsToSelector:@selector(videoPlayerNodeDidPlayToEnd:)];
    _delegateFlags.delegateVideoNodeShouldChangeState = [_delegate respondsToSelector:@selector(videoPlayerNode:shouldChangeVideoNodeStateTo:)];
    _delegateFlags.delegateTimeLabelAttributedString = [_delegate respondsToSelector:@selector(videoPlayerNode:timeStringForTimeLabelType:forTime:)];
    _delegateFlags.delegatePlaybackButtonTint = [_delegate respondsToSelector:@selector(videoPlayerNodePlaybackButtonTint:)];
    _delegateFlags.delegateDidTapVideoPlayerNode = [_delegate respondsToSelector:@selector(didTapVideoPlayerNode:)];
    _delegateFlags.delegateVideoPlayerNodeDidSetCurrentItem = [_delegate respondsToSelector:@selector(videoPlayerNode:didSetCurrentItem:)];
    _delegateFlags.delegateVideoPlayerNodeDidStallAtTimeInterval = [_delegate respondsToSelector:@selector(videoPlayerNode:didStallAtTimeInterval:)];
    _delegateFlags.delegateVideoPlayerNodeDidStartInitialLoading = [_delegate respondsToSelector:@selector(videoPlayerNodeDidStartInitialLoading:)];
    _delegateFlags.delegateVideoPlayerNodeDidFinishInitialLoading = [_delegate respondsToSelector:@selector(videoPlayerNodeDidFinishInitialLoading:)];
    _delegateFlags.delegateVideoPlayerNodeDidRecoverFromStall = [_delegate respondsToSelector:@selector(videoPlayerNodeDidRecoverFromStall:)];
  }
}

- (void)setControlsDisabled:(BOOL)controlsDisabled
{
  if (_controlsDisabled == controlsDisabled) {
    return;
  }
  
  _controlsDisabled = controlsDisabled;

  if (_controlsDisabled && _cachedControls.count > 0) {
    [self removeControls];
  } else if (!_controlsDisabled) {
    [self createControls];
  }
}

- (void)setShouldAutoPlay:(BOOL)shouldAutoPlay
{
  if (_shouldAutoPlay == shouldAutoPlay) {
    return;
  }
  _shouldAutoPlay = shouldAutoPlay;
  _videoNode.shouldAutoplay = _shouldAutoPlay;
}

- (void)setShouldAutoRepeat:(BOOL)shouldAutoRepeat
{
  if (_shouldAutoRepeat == shouldAutoRepeat) {
    return;
  }
  _shouldAutoRepeat = shouldAutoRepeat;
  _videoNode.shouldAutorepeat = _shouldAutoRepeat;
}

- (void)setMuted:(BOOL)muted
{
  if (_muted == muted) {
    return;
  }
  _muted = muted;
  _videoNode.muted = _muted;
}

- (void)setPeriodicTimeObserverTimescale:(int32_t)periodicTimeObserverTimescale
{
  if (_periodicTimeObserverTimescale == periodicTimeObserverTimescale) {
    return;
  }
  _periodicTimeObserverTimescale = periodicTimeObserverTimescale;
  _videoNode.periodicTimeObserverTimescale = _periodicTimeObserverTimescale;
}

- (NSString *)gravity
{
  if (_gravity == nil) {
    _gravity = _videoNode.gravity;
  }
  return _gravity;
}

- (void)setGravity:(NSString *)gravity
{
  if (_gravity == gravity) {
    return;
  }
  _gravity = gravity;
  _videoNode.gravity = _gravity;
}

- (ASVideoNodePlayerState)playerState
{
  return _videoNode.playerState;
}

- (BOOL)shouldAggressivelyRecoverFromStall
{
  return _videoNode.shouldAggressivelyRecoverFromStall;
}

- (void) setPlaceholderImageURL:(NSURL *)placeholderImageURL
{
  _videoNode.URL = placeholderImageURL;
}

- (NSURL*) placeholderImageURL
{
  return _videoNode.URL;
}

- (void)setShouldAggressivelyRecoverFromStall:(BOOL)shouldAggressivelyRecoverFromStall
{
  if (_shouldAggressivelyRecoverFromStall == shouldAggressivelyRecoverFromStall) {
    return;
  }
  _shouldAggressivelyRecoverFromStall = shouldAggressivelyRecoverFromStall;
  _videoNode.shouldAggressivelyRecoverFromStall = _shouldAggressivelyRecoverFromStall;
}

#pragma mark - Helpers
- (NSString *)timeStringForCMTime:(CMTime)time forTimeLabelType:(ASVideoPlayerNodeControlType)type
{
  if (_delegateFlags.delegateTimeLabelAttributedString) {
    return [_delegate videoPlayerNode:self timeStringForTimeLabelType:type forTime:time];
  }

  NSUInteger dTotalSeconds = CMTimeGetSeconds(time);

  NSUInteger dHours = floor(dTotalSeconds / 3600);
  NSUInteger dMinutes = floor(dTotalSeconds % 3600 / 60);
  NSUInteger dSeconds = floor(dTotalSeconds % 3600 % 60);

  NSString *videoDurationText;
  if (dHours > 0) {
    videoDurationText = [NSString stringWithFormat:@"%i:%02i:%02i", (int)dHours, (int)dMinutes, (int)dSeconds];
  } else {
    videoDurationText = [NSString stringWithFormat:@"%02i:%02i", (int)dMinutes, (int)dSeconds];
  }
  return videoDurationText;
}

@end

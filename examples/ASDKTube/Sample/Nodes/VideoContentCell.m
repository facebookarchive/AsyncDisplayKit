//
//  VideoContentCell.m
//  Sample
//
//  Created by Erekle on 5/14/16.
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

#import "VideoContentCell.h"
#import "ASVideoPlayerNode.h"
#import "Utilities.h"

#define AVATAR_IMAGE_HEIGHT     30
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5

@interface VideoContentCell () <ASVideoPlayerNodeDelegate>

@end

@implementation VideoContentCell
{
  VideoModel *_videoModel;
  ASTextNode *_titleNode;
  ASNetworkImageNode *_avatarNode;
  ASVideoPlayerNode *_videoPlayerNode;
  ASControlNode *_likeButtonNode;
  ASButtonNode *_muteButtonNode;
}

- (instancetype)initWithVideoObject:(VideoModel *)video
{
  self = [super init];
  if (self) {
    _videoModel = video;

    _titleNode = [[ASTextNode alloc] init];
    _titleNode.attributedText = [[NSAttributedString alloc] initWithString:_videoModel.title attributes:[self titleNodeStringOptions]];
    _titleNode.flexGrow = YES;
    [self addSubnode:_titleNode];

    _avatarNode = [[ASNetworkImageNode alloc] init];
    _avatarNode.URL = _videoModel.avatarUrl;

    [_avatarNode setImageModificationBlock:^UIImage *(UIImage *image) {
      CGSize profileImageSize = CGSizeMake(AVATAR_IMAGE_HEIGHT, AVATAR_IMAGE_HEIGHT);
      return [image makeCircularImageWithSize:profileImageSize];
    }];

    [self addSubnode:_avatarNode];

    _likeButtonNode = [[ASControlNode alloc] init];
    _likeButtonNode.backgroundColor = [UIColor redColor];
    [self addSubnode:_likeButtonNode];

    _muteButtonNode = [[ASButtonNode alloc] init];
    _muteButtonNode.preferredFrameSize = CGSizeMake(16.0, 22.0);
    [_muteButtonNode addTarget:self action:@selector(didTapMuteButton) forControlEvents:ASControlNodeEventTouchUpInside];

    _videoPlayerNode = [[ASVideoPlayerNode alloc] initWithUrl:_videoModel.url loadAssetWhenNodeBecomesVisible:YES];
    _videoPlayerNode.delegate = self;
    _videoPlayerNode.backgroundColor = [UIColor blackColor];
    [self addSubnode:_videoPlayerNode];

    [self setMuteButtonIcon];
  }
  return self;
}

- (NSDictionary*)titleNodeStringOptions
{
  return @{
     NSFontAttributeName : [UIFont systemFontOfSize:14.0],
     NSForegroundColorAttributeName: [UIColor blackColor]
  };
}

- (ASLayoutSpec*)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGFloat fullWidth = [UIScreen mainScreen].bounds.size.width;
  _videoPlayerNode.preferredFrameSize = CGSizeMake(fullWidth, fullWidth * 9 / 16);
  _avatarNode.preferredFrameSize = CGSizeMake(AVATAR_IMAGE_HEIGHT, AVATAR_IMAGE_HEIGHT);
  _likeButtonNode.preferredFrameSize = CGSizeMake(50.0, 26.0);

  ASStackLayoutSpec *headerStack  = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStack.spacing = HORIZONTAL_BUFFER;
  headerStack.alignItems = ASStackLayoutAlignItemsCenter;
  [headerStack setChildren:@[ _avatarNode, _titleNode]];

  UIEdgeInsets headerInsets      = UIEdgeInsetsMake(HORIZONTAL_BUFFER, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:headerInsets child:headerStack];

  ASStackLayoutSpec *bottomControlsStack  = [ASStackLayoutSpec horizontalStackLayoutSpec];
  bottomControlsStack.spacing = HORIZONTAL_BUFFER;
  bottomControlsStack.alignItems = ASStackLayoutAlignItemsCenter;
  [bottomControlsStack setChildren:@[ _likeButtonNode]];

  UIEdgeInsets bottomControlsInsets       = UIEdgeInsetsMake(HORIZONTAL_BUFFER, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *bottomControlsInset  = [ASInsetLayoutSpec insetLayoutSpecWithInsets:bottomControlsInsets child:bottomControlsStack];


  ASStackLayoutSpec *verticalStack   = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.alignItems           = ASStackLayoutAlignItemsStretch;
  [verticalStack setChildren:@[ headerInset, _videoPlayerNode, bottomControlsInset ]];
  return verticalStack;
}

- (void)setMuteButtonIcon
{
  if (_videoPlayerNode.muted) {
    [_muteButtonNode setImage:[UIImage imageNamed:@"ico-mute"] forState:ASControlStateNormal];
  } else {
    [_muteButtonNode setImage:[UIImage imageNamed:@"ico-unmute"] forState:ASControlStateNormal];
  }
}

- (void)didTapMuteButton
{
  _videoPlayerNode.muted = !_videoPlayerNode.muted;
  [self setMuteButtonIcon];
}

#pragma mark - ASVideoPlayerNodeDelegate
- (void)didTapVideoPlayerNode:(ASVideoPlayerNode *)videoPlayer
{
  if (_videoPlayerNode.playerState == ASVideoNodePlayerStatePlaying) {
    NSLog(@"TRANSITION");
    _videoPlayerNode.controlsDisabled = !_videoPlayerNode.controlsDisabled;
    [_videoPlayerNode pause];
  } else {
    [_videoPlayerNode play];
  }
}

- (NSDictionary *)videoPlayerNodeCustomControls:(ASVideoPlayerNode *)videoPlayer
{
  return @{
    @"muteControl" : _muteButtonNode
  };
}

- (NSArray *)controlsForControlBar:(NSDictionary *)availableControls
{
  NSMutableArray *controls = [[NSMutableArray alloc] init];

  if (availableControls[ @(ASVideoPlayerNodeControlTypePlaybackButton) ]) {
    [controls addObject:availableControls[ @(ASVideoPlayerNodeControlTypePlaybackButton) ]];
  }

  if (availableControls[ @(ASVideoPlayerNodeControlTypeElapsedText) ]) {
    [controls addObject:availableControls[ @(ASVideoPlayerNodeControlTypeElapsedText) ]];
  }

  if (availableControls[ @(ASVideoPlayerNodeControlTypeScrubber) ]) {
    [controls addObject:availableControls[ @(ASVideoPlayerNodeControlTypeScrubber) ]];
  }

  if (availableControls[ @(ASVideoPlayerNodeControlTypeDurationText) ]) {
    [controls addObject:availableControls[ @(ASVideoPlayerNodeControlTypeDurationText) ]];
  }

  return controls;
}

#pragma mark - Layout
- (ASLayoutSpec*)videoPlayerNodeLayoutSpec:(ASVideoPlayerNode *)videoPlayer forControls:(NSDictionary *)controls forMaximumSize:(CGSize)maxSize
{
  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;

  UIEdgeInsets insets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);

  if (controls[ @(ASVideoPlayerNodeControlTypeScrubber) ]) {
    ASDisplayNode *scrubber = controls[ @(ASVideoPlayerNodeControlTypeScrubber) ];
    scrubber.preferredFrameSize = CGSizeMake(maxSize.width, 44.0);
  }

  NSArray *controlBarControls = [self controlsForControlBar:controls];
  NSMutableArray *topBarControls = [[NSMutableArray alloc] init];

  //Our custom control
  if (controls[@"muteControl"]) {
    [topBarControls addObject:controls[@"muteControl"]];
  }


  ASStackLayoutSpec *topBarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                          spacing:10.0
                                                                   justifyContent:ASStackLayoutJustifyContentStart
                                                                       alignItems:ASStackLayoutAlignItemsCenter
                                                                         children:topBarControls];

  ASInsetLayoutSpec *topBarInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:topBarSpec];

  ASStackLayoutSpec *controlbarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                              spacing:10.0
                                                                       justifyContent:ASStackLayoutJustifyContentStart
                                                                           alignItems:ASStackLayoutAlignItemsCenter
                                                                             children: controlBarControls ];
  controlbarSpec.alignSelf = ASStackLayoutAlignSelfStretch;



  ASInsetLayoutSpec *controlbarInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:controlbarSpec];

  controlbarInsetSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  ASStackLayoutSpec *mainVerticalStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:0.0
                                                                          justifyContent:ASStackLayoutJustifyContentStart
                                                                              alignItems:ASStackLayoutAlignItemsStart
                                                                                children:@[topBarInsetSpec, spacer, controlbarInsetSpec]];

  return mainVerticalStack;

}
@end

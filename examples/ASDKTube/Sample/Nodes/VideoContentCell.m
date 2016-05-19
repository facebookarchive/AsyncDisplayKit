//
//  VideoContentCell.m
//  Sample
//
//  Created by Erekle on 5/14/16.
//  Copyright © 2016 Facebook. All rights reserved.
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

    _videoPlayerNode = [[ASVideoPlayerNode alloc] initWithUrl:_videoModel.url];
    _videoPlayerNode.delegate = self;
    _videoPlayerNode.backgroundColor = [UIColor blackColor];
    [self addSubnode:_videoPlayerNode];
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

#pragma mark - ASVideoPlayerNodeDelegate
- (void)didTapVideoPlayerNode:(ASVideoPlayerNode *)videoPlayer
{
  if (_videoPlayerNode.isPlaying) {
    NSLog(@"TRANSITION");
    [_videoPlayerNode pause];
  } else {
    [_videoPlayerNode play];
  }
}

/*- (NSArray *)videoPlayerNodeNeededControls:(ASVideoPlayerNode *)videoPlayer
{
  return @[ @(ASVideoPlayerNodeControlTypePlaybackButton) ];
}*/

/*- (ASLayoutSpec *)videoPlayerNodeLayoutSpec:(ASVideoPlayerNode *)videoPlayer forControls:(NSDictionary *)controls forMaximumSize:(CGSize)maxSize
{
  NSMutableArray *bottomControls = [[NSMutableArray alloc] init];

  ASDisplayNode *playbackButtonNode = controls[@(ASVideoPlayerNodeControlTypePlaybackButton)];

  if (playbackButtonNode) {
    [bottomControls addObject:playbackButtonNode];
  }

  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;

  ASStackLayoutSpec *controlbarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
  spacing:10.0
  justifyContent:ASStackLayoutJustifyContentStart
  alignItems:ASStackLayoutAlignItemsCenter
  children:bottomControls];
  controlbarSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  UIEdgeInsets insets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);

  ASInsetLayoutSpec *controlbarInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:controlbarSpec];

  controlbarInsetSpec.alignSelf = ASStackLayoutAlignSelfStretch;

  ASStackLayoutSpec *mainVerticalStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
  spacing:0.0
  justifyContent:ASStackLayoutJustifyContentStart
  alignItems:ASStackLayoutAlignItemsStart
  children:@[ spacer, controlbarInsetSpec ]];


  return mainVerticalStack;
}*/
@end

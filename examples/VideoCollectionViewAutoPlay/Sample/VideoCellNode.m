//
//  VideoCellNode.m
//  Sample
//
//  Created by Erekle on 3/14/16.
//  Copyright © 2016 facebook. All rights reserved.
//

#import "VideoCellNode.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASVideoNode.h>

static const CGFloat kOuterPadding = 10.0f;

@implementation VideoCellNode{
  ASVideoNode *_asVideoNode;
  ASTextNode  *_descNode;
  ASDisplayNode *_bottomSeparator;
  BOOL _scrollViewStopped;
  CGFloat _videoHeight;
}
- (instancetype)init{
  self = [super init];
  if(self){
    [self privateInit];
  }
  return self;
}

- (void)privateInit{
  _asVideoNode = [[ASVideoNode alloc] init];
  _asVideoNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
  _asVideoNode.muted = YES;
  _asVideoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-753fe655-86bb-46da-89b7-aa59c60e49c0-niccage.mp4"]];
  [self addSubnode:_asVideoNode];
  
  _descNode = [[ASTextNode alloc] init];
  _descNode.attributedString = [[NSAttributedString alloc] initWithString:[self placeHolderText]
                                                               attributes:[self textStyle]];
  
  [self addSubnode:_descNode];
  
  _bottomSeparator = [[ASDisplayNode alloc] init];
  _bottomSeparator.backgroundColor = [UIColor colorWithRed:0.686 green:0.718 blue:0.749 alpha:0.2];
  _bottomSeparator.layerBacked = YES;
  [self addSubnode:_bottomSeparator];
}

- (void)layout{
  [super layout];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _videoHeight = constrainedSize.max.width/1.777;
  _bottomSeparator.preferredFrameSize = CGSizeMake(constrainedSize.max.width, 1.0);
  _asVideoNode.preferredFrameSize = CGSizeMake(constrainedSize.max.width,_videoHeight);
  
  
  NSMutableArray *mainStackContent = [[NSMutableArray alloc] init];
  [mainStackContent addObject:_asVideoNode];
  [mainStackContent addObject:_descNode];
  [mainStackContent addObject:_bottomSeparator];
  
  ASStackLayoutSpec *contentSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                           spacing:16.0 justifyContent:ASStackLayoutJustifyContentStart
                                                                        alignItems:ASStackLayoutAlignItemsStart
                                                                          children:mainStackContent];
  
  
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
  insetSpec.insets = UIEdgeInsetsMake(kOuterPadding, kOuterPadding, kOuterPadding, kOuterPadding);
  insetSpec.child = contentSpec;
  return insetSpec;
}

- (void)cellNodeFinalVisibilityEvent:(ASCellNodeVisibilityEvent)event inScrollView:(UIScrollView *)scrollView withCellFrame:(CGRect)cellFrame
{
  if(event == ASCellNodeVisibilityEventVisible){
    self.backgroundColor = [UIColor greenColor];
    [_asVideoNode play];
  }else if(event == ASCellNodeVisibilityEventInvisible){
    [_asVideoNode pause];
  }
}

- (void)scrollView:(UIScrollView *)scrollView didStopScrolling:(BOOL)stoppedScrolling withCellFrame:(CGRect)cellFrame{
  _scrollViewStopped = stoppedScrolling;
  if (_scrollViewStopped) {
    
    CGRect intersect = CGRectIntersection(scrollView.bounds, cellFrame);
    float visibleHeight = CGRectGetHeight(intersect);
    CGFloat visiblePercentage = roundf(visibleHeight * 100.0 / cellFrame.size.height);
    NSLog(@"%f - %f - %f",cellFrame.size.height,visibleHeight,visiblePercentage);
    if (visiblePercentage > 80) {
      if(!_asVideoNode.isPlaying){
        [_asVideoNode play];
      }
    }else{
      if(_asVideoNode.isPlaying){
        [_asVideoNode pause];
      }
    }
  } else {
    if(_asVideoNode.isPlaying){
      [_asVideoNode pause];
    }
  }
}

//- (void)cellNodeVisibilityEvent:(ASCellNodeVisibilityEvent)event inScrollView:(UIScrollView *)scrollView withCellFrame:(CGRect)cellFrame
//{
//  if(event == ASCellNodeVisibilityEventVisible && _scrollViewStopped){
//    //[_asVideoNode play];
//  }else if(event == ASCellNodeVisibilityEventInvisible){
//    //[_asVideoNode pause];
//  }
//}

- (NSDictionary *)textStyle
{
  UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:15.0f];
  
  NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  style.paragraphSpacing = 0.5 * font.lineHeight;
  style.hyphenationFactor = 1.0;
  
  return @{ NSFontAttributeName: font,
            NSParagraphStyleAttributeName: style };
}

- (NSString*)placeHolderText{
  return @"Kitty ipsum dolor sit amet, purr sleep on your face lay down in your way biting, sniff tincidunt a etiam fluffy fur judging you stuck in a tree kittens.";
}
@end

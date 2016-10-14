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
#import <AsyncDisplayKit/ASVideoPlayerNode.h>
#import "VideoModel.h"
#import "VideoContentCell.h"

@interface ViewController()<ASVideoPlayerNodeDelegate, ASTableDelegate, ASTableDataSource>
@property (nonatomic, strong) ASVideoPlayerNode *videoPlayerNode;
@end

@implementation ViewController
{
  ASTableNode *_tableNode;
  NSMutableArray<VideoModel*> *_videoFeedData;
}

- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] init];
  _tableNode.delegate = self;
  _tableNode.dataSource = self;

  if (!(self = [super initWithNode:_tableNode])) {
    return nil;
  }
  
  return self;
}

- (void)loadView
{
  [super loadView];

  _videoFeedData = [[NSMutableArray alloc] initWithObjects:[[VideoModel alloc] init], [[VideoModel alloc] init], nil];

  [_tableNode reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  //[self.view addSubnode:self.videoPlayerNode];
  
  //[self.videoPlayerNode setNeedsLayout];
}

#pragma mark - ASCollectionDelegate - ASCollectionDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
  return _videoFeedData.count;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  VideoModel *videoObject = [_videoFeedData objectAtIndex:indexPath.row];
  VideoContentCell *cellNode = [[VideoContentCell alloc] initWithVideoObject:videoObject];
  return cellNode;
}

//- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath{
//  CGFloat fullWidth = [UIScreen mainScreen].bounds.size.width;
//  return ASSizeRangeMake(CGSizeMake(fullWidth, 0.0), CGSizeMake(fullWidth, 400.0));
//}

- (ASVideoPlayerNode *)videoPlayerNode;
{
  if (_videoPlayerNode) {
    return _videoPlayerNode;
  }
  
  NSURL *fileUrl = [NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"];

  _videoPlayerNode = [[ASVideoPlayerNode alloc] initWithUrl:fileUrl];
  _videoPlayerNode.delegate = self;
//  _videoPlayerNode.disableControls = YES;
//
//  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//    _videoPlayerNode.disableControls = NO;
//  });

  _videoPlayerNode.backgroundColor = [UIColor blackColor];

  return _videoPlayerNode;
}

#pragma mark - ASVideoPlayerNodeDelegate
//- (NSArray *)videoPlayerNodeNeededControls:(ASVideoPlayerNode *)videoPlayer
//{
//  return @[ @(ASVideoPlayerNodeControlTypePlaybackButton),
//            @(ASVideoPlayerNodeControlTypeElapsedText),
//            @(ASVideoPlayerNodeControlTypeScrubber),
//            @(ASVideoPlayerNodeControlTypeDurationText) ];
//}
//
//- (UIColor *)videoPlayerNodeScrubberMaximumTrackTint:(ASVideoPlayerNode *)videoPlayer
//{
//  return [UIColor colorWithRed:1 green:1 blue:1 alpha:0.3];
//}
//
//- (UIColor *)videoPlayerNodeScrubberMinimumTrackTint:(ASVideoPlayerNode *)videoPlayer
//{
//  return [UIColor whiteColor];
//}
//
//- (UIColor *)videoPlayerNodeScrubberThumbTint:(ASVideoPlayerNode *)videoPlayer
//{
//  return [UIColor whiteColor];
//}
//
//- (NSDictionary *)videoPlayerNodeTimeLabelAttributes:(ASVideoPlayerNode *)videoPlayerNode timeLabelType:(ASVideoPlayerNodeControlType)timeLabelType
//{
//  NSDictionary *options;
//
//  if (timeLabelType == ASVideoPlayerNodeControlTypeElapsedText) {
//    options = @{
//                NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Medium" size:16.0],
//                NSForegroundColorAttributeName: [UIColor orangeColor]
//                };
//  } else if (timeLabelType == ASVideoPlayerNodeControlTypeDurationText) {
//    options = @{
//                NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Medium" size:16.0],
//                NSForegroundColorAttributeName: [UIColor redColor]
//                };
//  }
//
//  return options;
//}

/*- (ASLayoutSpec *)videoPlayerNodeLayoutSpec:(ASVideoPlayerNode *)videoPlayer
                                forControls:(NSDictionary *)controls
                         forConstrainedSize:(ASSizeRange)constrainedSize
{

  NSMutableArray *bottomControls = [[NSMutableArray alloc] init];
  NSMutableArray *topControls = [[NSMutableArray alloc] init];

  ASDisplayNode *scrubberNode = controls[@(ASVideoPlayerNodeControlTypeScrubber)];
  ASDisplayNode *playbackButtonNode = controls[@(ASVideoPlayerNodeControlTypePlaybackButton)];
  ASTextNode *elapsedTexNode = controls[@(ASVideoPlayerNodeControlTypeElapsedText)];
  ASTextNode *durationTexNode = controls[@(ASVideoPlayerNodeControlTypeDurationText)];

  if (playbackButtonNode) {
    [bottomControls addObject:playbackButtonNode];
  }

  if (scrubberNode) {
    scrubberNode.preferredFrameSize = CGSizeMake(constrainedSize.max.width, 44.0);
    [bottomControls addObject:scrubberNode];
  }

  if (elapsedTexNode) {
    [topControls addObject:elapsedTexNode];
  }

  if (durationTexNode) {
    [topControls addObject:durationTexNode];
  }

  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;

  ASStackLayoutSpec *topBarSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                              spacing:10.0
                                                                       justifyContent:ASStackLayoutJustifyContentCenter
                                                                           alignItems:ASStackLayoutAlignItemsCenter
                                                                             children:topControls];



  UIEdgeInsets topBarSpecInsets = UIEdgeInsetsMake(20.0, 10.0, 0.0, 10.0);

  ASInsetLayoutSpec *topBarSpecInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:topBarSpecInsets child:topBarSpec];
  topBarSpecInsetSpec.alignSelf = ASStackLayoutAlignSelfStretch;

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
                                                                                children:@[ topBarSpecInsetSpec, spacer, controlbarInsetSpec ]];


  return mainVerticalStack;
}*/

@end

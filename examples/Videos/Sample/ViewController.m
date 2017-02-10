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

@interface ViewController()<ASVideoNodeDelegate>
@property (nonatomic, strong) ASDisplayNode *rootNode;
@property (nonatomic, strong) ASVideoNode *guitarVideoNode;
@end

@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // Root node for the view controller
  _rootNode = [ASDisplayNode new];
  _rootNode.frame = self.view.bounds;
  _rootNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  
  ASVideoNode *guitarVideoNode = self.guitarVideoNode;
  [_rootNode addSubnode:self.guitarVideoNode];
  
  ASVideoNode *nicCageVideoNode = self.nicCageVideoNode;
  [_rootNode addSubnode:nicCageVideoNode];
  
  // Video node with custom play button
  ASVideoNode *simonVideoNode = self.simonVideoNode;
  [_rootNode addSubnode:simonVideoNode];
  
  ASVideoNode *hlsVideoNode = self.hlsVideoNode;
  [_rootNode addSubnode:hlsVideoNode];
  
  CGSize mainScreenBoundsSize = [UIScreen mainScreen].bounds.size;
  
  _rootNode.layoutSpecBlock = ^ASLayoutSpec *(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    
    // Layout all nodes absolute in a static layout spec
    guitarVideoNode.style.preferredSize = CGSizeMake(mainScreenBoundsSize.width, mainScreenBoundsSize.height / 3.0);
    guitarVideoNode.style.layoutPosition = CGPointMake(0, 0);
    
    nicCageVideoNode.style.preferredSize = CGSizeMake(mainScreenBoundsSize.width/2, mainScreenBoundsSize.height / 3.0);
    nicCageVideoNode.style.layoutPosition = CGPointMake(mainScreenBoundsSize.width / 2.0, mainScreenBoundsSize.height / 3.0);
    
    simonVideoNode.style.preferredSize = CGSizeMake(mainScreenBoundsSize.width/2, mainScreenBoundsSize.height / 3.0);
    simonVideoNode.style.layoutPosition = CGPointMake(0.0, mainScreenBoundsSize.height - (mainScreenBoundsSize.height / 3.0));
    
    hlsVideoNode.style.preferredSize = CGSizeMake(mainScreenBoundsSize.width / 2.0, mainScreenBoundsSize.height / 3.0);
    hlsVideoNode.style.layoutPosition = CGPointMake(0.0, mainScreenBoundsSize.height / 3.0);
    
    return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[guitarVideoNode, nicCageVideoNode, simonVideoNode, hlsVideoNode]];
  };
  
  // Delay setting video asset for testing that the transition between the placeholder and setting/playing the asset is seamless.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    hlsVideoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear1/prog_index.m3u8"]];
    [hlsVideoNode play];
  });
  
  [self.view addSubnode:_rootNode];
}

#pragma mark - Getter / Setter

- (ASVideoNode *)guitarVideoNode;
{
  if (_guitarVideoNode) {
    return _guitarVideoNode;
  }
  
  _guitarVideoNode = [[ASVideoNode alloc] init];
  _guitarVideoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"]];
  _guitarVideoNode.gravity = AVLayerVideoGravityResizeAspectFill;
  _guitarVideoNode.backgroundColor = [UIColor lightGrayColor];
  _guitarVideoNode.periodicTimeObserverTimescale = 1; //Default is 100
  _guitarVideoNode.delegate = self;
  
  return _guitarVideoNode;
}

- (ASVideoNode *)nicCageVideoNode;
{
  ASVideoNode *nicCageVideoNode = [[ASVideoNode alloc] init];
  nicCageVideoNode.delegate = self;
  nicCageVideoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-753fe655-86bb-46da-89b7-aa59c60e49c0-niccage.mp4"]];
  nicCageVideoNode.gravity = AVLayerVideoGravityResize;
  nicCageVideoNode.backgroundColor = [UIColor lightGrayColor];
  nicCageVideoNode.shouldAutorepeat = YES;
  nicCageVideoNode.shouldAutoplay = YES;
  nicCageVideoNode.muted = YES;
  
  return nicCageVideoNode;
}

- (ASVideoNode *)simonVideoNode
{
  ASVideoNode *simonVideoNode = [[ASVideoNode alloc] init];
  
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"simon" ofType:@"mp4"]];
  simonVideoNode.asset = [AVAsset assetWithURL:url];
  simonVideoNode.gravity = AVLayerVideoGravityResizeAspect;
  simonVideoNode.backgroundColor = [UIColor lightGrayColor];
  simonVideoNode.shouldAutorepeat = YES;
  simonVideoNode.shouldAutoplay = YES;
  simonVideoNode.muted = YES;
  
  return simonVideoNode;
}

- (ASVideoNode *)hlsVideoNode;
{
  ASVideoNode *hlsVideoNode = [[ASVideoNode alloc] init];
  
  hlsVideoNode.delegate = self;
  hlsVideoNode.gravity = AVLayerVideoGravityResize;
  hlsVideoNode.backgroundColor = [UIColor redColor]; // Should not be seen after placeholder image is loaded
  hlsVideoNode.shouldAutorepeat = YES;
  hlsVideoNode.shouldAutoplay = YES;
  hlsVideoNode.muted = YES;
 
  // Placeholder image
  hlsVideoNode.URL = [NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/en/5/52/Testcard_F.jpg"];
  
  return hlsVideoNode;
}

- (ASButtonNode *)playButton;
{
  ASButtonNode *playButtonNode = [[ASButtonNode alloc] init];
  
  UIImage *image = [UIImage imageNamed:@"playButton@2x.png"];
  [playButtonNode setImage:image forState:UIControlStateNormal];
  [playButtonNode setImage:[UIImage imageNamed:@"playButtonSelected@2x.png"] forState:UIControlStateHighlighted];
  
  // Change placement of play button if necessary
  //playButtonNode.contentHorizontalAlignment = ASHorizontalAlignmentStart;
  //playButtonNode.contentVerticalAlignment = ASVerticalAlignmentCenter;
  
  return playButtonNode;
}

#pragma mark - Actions

- (void)didTapVideoNode:(ASVideoNode *)videoNode
{
  if (videoNode == self.guitarVideoNode) {
    if (videoNode.playerState == ASVideoNodePlayerStatePlaying) {
      [videoNode pause];
    } else if(videoNode.playerState == ASVideoNodePlayerStateLoading) {
      [videoNode pause];
    } else {
      [videoNode play];
    }
    return;
  }
  if (videoNode.player.muted == YES) {
    videoNode.player.muted = NO;
  } else {
    videoNode.player.muted = YES;
  }
}

#pragma mark - ASVideoNodeDelegate

- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState
{
  //Ignore nicCageVideo
  if (videoNode != _guitarVideoNode) {
    return;
  }
  
  if (toState == ASVideoNodePlayerStatePlaying) {
    NSLog(@"guitarVideoNode is playing");
  } else if (toState == ASVideoNodePlayerStateFinished) {
    NSLog(@"guitarVideoNode finished");
  } else if (toState == ASVideoNodePlayerStateLoading) {
    NSLog(@"guitarVideoNode is buffering");
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToTimeInterval:(NSTimeInterval)timeInterval
{
  if (videoNode != _guitarVideoNode) {
    return;
  }
  
  NSLog(@"guitarVideoNode playback time is: %f",timeInterval);
}

@end

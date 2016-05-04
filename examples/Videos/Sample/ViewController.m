/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ViewController.h"

@interface ViewController()<ASVideoNodeDelegate>
@property (nonatomic, strong) ASVideoNode *guitarVideoNode;
@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  [self.view addSubnode:self.guitarVideoNode];
  
  ASVideoNode *nicCageVideo = [self nicCageVideo];
  [self.view addSubnode:nicCageVideo];
  
  ASVideoNode *simonVideo = [self simonVideo];
  [self.view addSubnode:simonVideo];
}

- (ASVideoNode *)guitarVideoNode;
{
  if (_guitarVideoNode) {
    return _guitarVideoNode;
  }
  _guitarVideoNode = [[ASVideoNode alloc] init];
  
  _guitarVideoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"]];
  
  _guitarVideoNode.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/3);
  
  _guitarVideoNode.gravity = AVLayerVideoGravityResizeAspectFill;
  
  _guitarVideoNode.backgroundColor = [UIColor lightGrayColor];
  
  _guitarVideoNode.periodicTimeObserverTimescale = 1; //Default is 100
  
  _guitarVideoNode.delegate = self;
  
  return _guitarVideoNode;
}

- (ASVideoNode *)nicCageVideo;
{
  ASVideoNode *nicCageVideo = [[ASVideoNode alloc] init];
  
  nicCageVideo.delegate = self;
  
  nicCageVideo.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-753fe655-86bb-46da-89b7-aa59c60e49c0-niccage.mp4"]];
  
  nicCageVideo.frame = CGRectMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3, [UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3);
  
  nicCageVideo.gravity = AVLayerVideoGravityResize;
  
  nicCageVideo.backgroundColor = [UIColor lightGrayColor];
  nicCageVideo.shouldAutorepeat = YES;
  nicCageVideo.shouldAutoplay = YES;
  nicCageVideo.muted = YES;
  
  return nicCageVideo;
}

- (ASVideoNode *)simonVideo;
{
  ASVideoNode *simonVideo = [[ASVideoNode alloc] init];
  
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"simon" ofType:@"mp4"]];
  simonVideo.asset = [AVAsset assetWithURL:url];
  
  simonVideo.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.height - ([UIScreen mainScreen].bounds.size.height/3), [UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3);
  
  simonVideo.gravity = AVLayerVideoGravityResizeAspect;
  
  simonVideo.backgroundColor = [UIColor lightGrayColor];
  simonVideo.shouldAutorepeat = YES;
  simonVideo.shouldAutoplay = YES;
  simonVideo.muted = YES;
  
  return simonVideo;
}

- (ASButtonNode *)playButton;
{
  ASButtonNode *playButton = [[ASButtonNode alloc] init];
  
  UIImage *image = [UIImage imageNamed:@"playButton@2x.png"];
  [playButton setImage:image forState:ASControlStateNormal];
  [playButton measure:CGSizeMake(50, 50)];
  playButton.bounds = CGRectMake(0, 0, playButton.calculatedSize.width, playButton.calculatedSize.height);
  playButton.position = CGPointMake([UIScreen mainScreen].bounds.size.width/4, ([UIScreen mainScreen].bounds.size.height/3)/2);
  [playButton setImage:[UIImage imageNamed:@"playButtonSelected@2x.png"] forState:ASControlStateHighlighted];
  
  return playButton;
}

- (void)videoNodeWasTapped:(ASVideoNode *)videoNode
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
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toSate
{
  //Ignore nicCageVideo
  if (videoNode != _guitarVideoNode) {
    return;
  }
  
  if (toSate == ASVideoNodePlayerStatePlaying) {
    NSLog(@"guitarVideoNode is playing");
  } else if (toSate == ASVideoNodePlayerStateFinished) {
    NSLog(@"guitarVideoNode finished");
  } else if (toSate == ASVideoNodePlayerStateLoading) {
    NSLog(@"guitarVideoNode is buffering");
  }
}

- (void)videoNode:(ASVideoNode *)videoNode didPlayToSecond:(NSTimeInterval)second
{
  if (videoNode != _guitarVideoNode) {
    return;
  }
  
  NSLog(@"guitarVideoNode playback time is: %f",second);
}

@end
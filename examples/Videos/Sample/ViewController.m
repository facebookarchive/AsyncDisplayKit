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

@interface ViewController()
@property (nonatomic) ASVideoNode *videoNode;
@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  ASVideoNode *guitarVideo = [self guitarVideo];
  [self.view addSubnode:guitarVideo];
  
  ASVideoNode *nicCageVideo = [self nicCageVideo];
  [self.view addSubnode:nicCageVideo];
  
  ASVideoNode *simonVideo = [self simonVideo];
  [self.view addSubnode:simonVideo];
}

- (ASVideoNode *)guitarVideo;
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"]];
  
  videoNode.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3);
  
  videoNode.gravity = ASVideoGravityResizeAspectFill;
  
  videoNode.backgroundColor = [UIColor lightGrayColor];
  
  videoNode.playButton = [self playButton];
  return videoNode;
}

- (ASVideoNode *)nicCageVideo;
{
  ASVideoNode *nicCageVideo = [[ASVideoNode alloc] init];
  
  nicCageVideo.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"http://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-753fe655-86bb-46da-89b7-aa59c60e49c0-niccage.mp4"]];
  
  nicCageVideo.frame = CGRectMake([UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3, [UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3);
  
  nicCageVideo.gravity = ASVideoGravityResize;
  
  nicCageVideo.backgroundColor = [UIColor lightGrayColor];
  nicCageVideo.autorepeat = YES;
  nicCageVideo.playButton = [self playButton];

  return nicCageVideo;
}

- (ASVideoNode *)simonVideo;
{
  ASVideoNode *simonVideo = [[ASVideoNode alloc] init];
  
  NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"simon" ofType:@"mp4"]];
  simonVideo.asset = [AVAsset assetWithURL:url];
  
  simonVideo.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.height - ([UIScreen mainScreen].bounds.size.height/3), [UIScreen mainScreen].bounds.size.width/2, [UIScreen mainScreen].bounds.size.height/3);
  
  simonVideo.gravity = ASVideoGravityResizeAspect;
  
  simonVideo.backgroundColor = [UIColor lightGrayColor];
  simonVideo.autorepeat = YES;
  simonVideo.playButton = [self playButton];
  simonVideo.shouldAutoplay = YES;
  
  return simonVideo;
}

- (ASButtonNode *)playButton;
{
  ASButtonNode *playButton = [[ASButtonNode alloc] init];
  
  UIImage *image = [UIImage imageNamed:@"playButton@2x.png"];
  [playButton setImage:image forState:ASButtonStateNormal];
  [playButton measure:CGSizeMake(50, 50)];
  playButton.bounds = CGRectMake(0, 0, playButton.calculatedSize.width, playButton.calculatedSize.height);
  playButton.position = CGPointMake([UIScreen mainScreen].bounds.size.width/4, ([UIScreen mainScreen].bounds.size.height/3)/2);
  [playButton setImage:[UIImage imageNamed:@"playButtonSelected@2x.png"] forState:ASButtonStateHighlighted];

  return playButton;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

@end

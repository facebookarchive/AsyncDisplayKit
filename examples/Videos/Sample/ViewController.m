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

  _videoNode = [[ASVideoNode alloc] init];

  _videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"]];
  
  _videoNode.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/3);
  
  _videoNode.backgroundColor = [UIColor lightGrayColor];
  
//  _videoNode.autorepeat = YES; //need to implement
//  _videoNode.autoPlay = YES; //need to implement
  
  ASButtonNode *playButton = [[ASButtonNode alloc] init];
  playButton.bounds = CGRectMake(0, 0, 150, 150);
  playButton.position = CGPointMake(_videoNode.bounds.size.width/2, _videoNode.bounds.size.height/2);
  
  UIImage *image = [UIImage imageNamed:@"playButton@2x.png"];
  [playButton setImage:image forState:ASButtonStateNormal];
  [playButton measure:CGSizeMake(100, 100)];
  
  _videoNode.playButton = playButton;
  
  _videoNode.gravity = ASVideoGravityResizeAspectFill;
  
  [self.view addSubnode:_videoNode];
  
//  NSLog(@"%@", _videoNode.asset);
  
//  ASButtonNode *playButton2 = [[ASButtonNode alloc] init];
////  playButton2.bounds = CGRectMake(0, 0, 50, 50);
//  
//  UIImage *image2 = [UIImage imageNamed:@"playButton@2x.png"];
//  [playButton2 setImage:image2 forState:ASButtonStateNormal];
//
////  playButton2.contentMode = UIViewContentModeScaleAspectFit;
//  playButton2.clipsToBounds = YES;
//  playButton2.layer.borderColor = [UIColor orangeColor].CGColor;
//  playButton2.layer.borderWidth = 1.0;
//  
//  [playButton2 measure:CGSizeMake(100, 100)];
////  playButton2.preferredFrameSize = CGSizeMake(100, 100);
//  playButton2.position = CGPointMake(150, 300);
//  playButton2.bounds = (CGRect){{0, 0}, playButton2.calculatedSize};
//  
//  [self.view addSubview:playButton2.view];
}

- (void)viewDidAppear:(BOOL)animated
{
  
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

@end

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
@property (nonatomic, strong) ASVideoPlayerNode *videoPlayerNode;
@end

@implementation ViewController

- (instancetype)init
{
  if (!(self = [super initWithNode:self.videoPlayerNode])) {
    return nil;
  }
  
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  //[self.view addSubnode:self.videoPlayerNode];
  
  //[self.videoPlayerNode setNeedsLayout];
}

- (ASVideoPlayerNode *)videoPlayerNode;
{
  if (_videoPlayerNode) {
    return _videoPlayerNode;
  }
  
  NSURL *fileUrl = [NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"];

  _videoPlayerNode = [[ASVideoPlayerNode alloc] initWithUrl:fileUrl];

  //_videoPlayerNode.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);

  _videoPlayerNode.backgroundColor = [UIColor blackColor];

  return _videoPlayerNode;
  
//  _guitarVideoNode = [[ASVideoNode alloc] init];
//  
//  _guitarVideoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-3045b261-7e93-4492-b7e5-5d6358376c9f-editedLiveAndDie.mov"]];
//  
//  _guitarVideoNode.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/3);
//  
//  _guitarVideoNode.gravity = AVLayerVideoGravityResizeAspectFill;
//  
//  _guitarVideoNode.backgroundColor = [UIColor lightGrayColor];
//  
//  _guitarVideoNode.periodicTimeObserverTimescale = 1; //Default is 100
//  
//  _guitarVideoNode.delegate = self;
//  
//  return _guitarVideoNode;
}

@end
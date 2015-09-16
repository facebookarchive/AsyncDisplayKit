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
#import "ScreenNode.h"

@interface ViewController() {
  ScreenNode *_screenNode;
}

@end

@implementation ViewController

- (instancetype)init
{
  ScreenNode *node = [[ScreenNode alloc] init];
  if (!(self = [super initWithNode:node]))
    return nil;

  _screenNode = node;

  // tap to reload
  UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reload:)];
  [_screenNode.textNode.view addGestureRecognizer:gr];

  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [_screenNode start];
}

- (void)reload:(id)sender {
  [_screenNode reload];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

@end

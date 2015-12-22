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


#import "ImageViewController.h"

@interface ImageViewController ()
@property (nonatomic) UIImageView *imageView;
@end

@implementation ImageViewController

- (instancetype)initWithImage:(UIImage *)image {
  if (!(self = [super init])) { return nil; }
  
  self.imageView = [[UIImageView alloc] initWithImage:image];
  
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self.view addSubview:self.imageView];
  
  UIGestureRecognizer *tap = [[UIGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
  [self.view addGestureRecognizer:tap];

  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)tapped;
{
  NSLog(@"tapped!");
}

- (void)viewWillLayoutSubviews
{
  self.imageView.frame = self.view.bounds;
}

@end

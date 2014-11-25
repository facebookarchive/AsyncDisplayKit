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

#import "CheapController.h"

@interface CheapController ()
{
  UILabel *_cheapLabel;
}

@end

@implementation CheapController

- (instancetype)init
{
  if (self = [super init]) {
    _cheapLabel = [[UILabel alloc] init];
    _cheapLabel.text = @"I'm a cheap date.";
    [_cheapLabel sizeToFit];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor whiteColor];
  [self.view addSubview:_cheapLabel];
}

- (void)viewDidLayoutSubviews
{
  _cheapLabel.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

@end

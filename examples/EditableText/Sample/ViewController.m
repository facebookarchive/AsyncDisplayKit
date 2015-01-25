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

#import <AsyncDisplayKit/AsyncDisplayKit.h>


@interface ViewController () <ASEditableTextNodeDelegate>
{
  ASEditableTextNode *_textNode;
}

@end


@implementation ViewController

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // simple editable text node.  here we use it synchronously, but it fully supports async layout & display
  _textNode = [[ASEditableTextNode alloc] init];
  _textNode.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.1f];

  // with placeholder text (displayed if the user hasn't entered text)
  NSDictionary *placeholderAttrs = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-LightItalic" size:18.0f] };
  _textNode.attributedPlaceholderText = [[NSAttributedString alloc] initWithString:@"Tap to type!"
                                                                        attributes:placeholderAttrs];

  // and typing attributes (style for any text the user enters)
  _textNode.typingAttributes = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:18.0f] };

  // the usual delegate methods are available; see ASEditableTextNodeDelegate
  _textNode.delegate = self;

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubview:_textNode.view];

  [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];
}

- (void)viewWillLayoutSubviews
{
  // place the text node in the top half of the screen, with a bit of padding
  _textNode.frame = CGRectMake(0, 20, self.view.bounds.size.width, (self.view.bounds.size.height / 2) - 40);
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)tap:(UITapGestureRecognizer *)sender
{
  // dismiss the keyboard when we tap outside the text field
  [_textNode resignFirstResponder];
}

@end

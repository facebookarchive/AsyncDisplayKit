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

#define NUMBER_ELEMENTS 2

@interface ViewController ()
{
  NSMutableArray <ASTextNode *> *_textNodes;
  NSMutableArray <UILabel *> *_textLabels;
  UIScrollView *_scrollView;
}

@end


@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _textNodes = [NSMutableArray array];
  _textLabels = [NSMutableArray array];
  
  _scrollView = [[UIScrollView alloc] init];
  [self.view addSubview:_scrollView];
  
  for (int i = 0; i < NUMBER_ELEMENTS; i++) {
    
    ASTextNode *node = [self createNodeForIndex:i];
    [_textNodes addObject:node];
    [_scrollView addSubnode:node];

    UILabel *label = [self createLabelForIndex:i];
    [_textLabels addObject:label];
    [_scrollView addSubview:label];
  }
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  CGFloat maxWidth = 0;
  CGFloat maxHeight = 0;
  
  CGRect frame = CGRectMake(50, 50, 0, 0);
  
  for (int i = 0; i < NUMBER_ELEMENTS; i++) {
    frame.size = [self sizeForIndex:i];
    [[_textNodes objectAtIndex:i] setFrame:frame];
    
    frame.origin.x += frame.size.width + 50;
    
    [[_textLabels objectAtIndex:i] setFrame:frame];
    
    if (frame.size.width > maxWidth) {
      maxWidth = frame.size.width;
    }
    if ((frame.size.height + frame.origin.y) > maxHeight) {
      maxHeight = frame.size.height + frame.origin.y;
    }
    
    frame.origin.x -= frame.size.width + 50;
    frame.origin.y += frame.size.height + 20;
  }
  
  _scrollView.frame = self.view.bounds;
  _scrollView.contentSize = CGSizeMake(maxWidth, maxHeight);
}

- (ASTextNode *)createNodeForIndex:(NSUInteger)index
{
  ASTextNode *node = [[ASTextNode alloc] init];
  node.attributedText = [self textForIndex:index];
  node.backgroundColor = [UIColor orangeColor];
  
  NSMutableAttributedString *string = [node.attributedText mutableCopy];
  
  switch (index) {
    case 0:                             // top justification (ASDK) vs. center justification (UILabel)
      node.maximumNumberOfLines = 3;
      return node;
      
    case 1:                             // default truncation attributed string color shouldn't match attributed text color (ASDK) vs. match (UIKit)
      node.maximumNumberOfLines = 3;
      [string addAttribute:NSForegroundColorAttributeName
                     value:[UIColor redColor]
                     range:NSMakeRange(0, [string length])];
      node.attributedText = string;
      return node;
  
    default:
      return nil;
  }
}

- (UILabel *)createLabelForIndex:(NSUInteger)index
{
  UILabel *label = [[UILabel alloc] init];
  label.attributedText = [self textForIndex:index];
  label.backgroundColor = [UIColor greenColor];
  
  NSMutableAttributedString *string = [label.attributedText mutableCopy];
  
  switch (index) {
    case 0:
      label.numberOfLines = 3;
      return label;
      
    case 1:
      label.numberOfLines = 3;
      [string addAttribute:NSForegroundColorAttributeName
                     value:[UIColor redColor]
                     range:NSMakeRange(0, [string length])];
      label.attributedText = string;
      return label;
    
    default:
      return nil;
  }
}

- (NSAttributedString *)textForIndex:(NSUInteger)index
{
  NSDictionary *attrs = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:12.0f] };

  switch (index) {
    case 0:
      return [[NSAttributedString alloc] initWithString:@"1\n2\n3\n4\n5" attributes:attrs];
      
    case 1:
      return [[NSAttributedString alloc] initWithString:@"1\n2\n3\n4\n5" attributes:attrs];
      
    default:
      return nil;
  }
}

- (CGSize)sizeForIndex:(NSUInteger)index
{
  switch (index) {
    case 0:
      return CGSizeMake(40, 100);
      
    case 1:
      return CGSizeMake(40, 100);
      
    default:
      return CGSizeZero;
  }
}

@end

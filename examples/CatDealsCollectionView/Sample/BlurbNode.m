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

#import "BlurbNode.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASHighlightOverlayLayer.h>

#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutSpec.h>

static CGFloat kFixedHeight = 75.0f;
static CGFloat kTextPadding = 10.0f;

@interface BlurbNode () <ASTextNodeDelegate>
{
  ASTextNode *_textNode;
}

@end


@implementation BlurbNode

#pragma mark -
#pragma mark ASCellNode.

+ (CGFloat)desiredHeightForWidth:(CGFloat)width {
  return kFixedHeight;
}

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  self.backgroundColor = [UIColor lightGrayColor];
  // create a text node
  _textNode = [[ASTextNode alloc] init];
  _textNode.maximumNumberOfLines = 2;

  // configure the node to support tappable links
  _textNode.delegate = self;
  _textNode.userInteractionEnabled = YES;

  // generate an attributed string using the custom link attribute specified above
  NSString *blurb = @"Kittens courtesy lorempixel.com \U0001F638 \nTitles courtesy of catipsum.com";
  NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:blurb];
  [string addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Light" size:16.0f] range:NSMakeRange(0, blurb.length)];
  [string addAttributes:@{
                          NSLinkAttributeName: [NSURL URLWithString:@"http://lorempixel.com/"],
                          NSForegroundColorAttributeName: [UIColor blueColor],
                          NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle | NSUnderlinePatternDot),
                          }
                  range:[blurb rangeOfString:@"lorempixel.com"]];
  [string addAttributes:@{
                          NSLinkAttributeName: [NSURL URLWithString:@"http://www.catipsum.com/"],
                          NSForegroundColorAttributeName: [UIColor blueColor],
                          NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle | NSUnderlinePatternDot),
                          } range:[blurb rangeOfString:@"catipsum.com"]];
  _textNode.attributedString = string;

  // add it as a subnode, and we're done
  [self addSubnode:_textNode];

  return self;
}

- (void)didLoad
{
  // enable highlighting now that self.layer has loaded -- see ASHighlightOverlayLayer.h
  self.layer.as_allowsHighlightDrawing = YES;

  [super didLoad];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASCenterLayoutSpec *centerSpec = [[ASCenterLayoutSpec alloc] init];
  centerSpec.centeringOptions = ASCenterLayoutSpecCenteringX;
  centerSpec.sizingOptions = ASCenterLayoutSpecSizingOptionMinimumY;
  centerSpec.child = _textNode;
  
  UIEdgeInsets padding =UIEdgeInsetsMake(kTextPadding, kTextPadding, kTextPadding, kTextPadding);
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:padding child:centerSpec];
}


#pragma mark -
#pragma mark ASTextNodeDelegate methods.

- (BOOL)textNode:(ASTextNode *)richTextNode shouldHighlightLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point
{
  // opt into link highlighting -- tap and hold the link to try it!  must enable highlighting on a layer, see -didLoad
  return YES;
}

- (void)textNode:(ASTextNode *)richTextNode tappedLinkAttribute:(NSString *)attribute value:(NSURL *)URL atPoint:(CGPoint)point textRange:(NSRange)textRange
{
  // the node tapped a link, open it
  [[UIApplication sharedApplication] openURL:URL];
}

@end

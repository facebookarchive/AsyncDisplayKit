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

#import "PlaceholderTextNode.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@interface PlaceholderTextNode ()
{
  CALayer *_placeholderLayer;
  BOOL _displayFinished;
}

@end

@implementation PlaceholderTextNode

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _placeholderLayer = [CALayer layer];
  _placeholderLayer.backgroundColor = [UIColor colorWithWhite:0.7f alpha:0.5f].CGColor;

  return self;
}

- (void)willEnterHierarchy
{
  [super willEnterHierarchy];

  if (!_displayFinished) {
    [self.layer addSublayer:_placeholderLayer];
  }
}

- (void)layout
{
  _placeholderLayer.frame = (CGRect){ CGPointZero, self.calculatedSize };
}

- (void)displayDidFinish
{
  _displayFinished = YES;
  [_placeholderLayer removeFromSuperlayer];
  [super displayDidFinish];
}

@end

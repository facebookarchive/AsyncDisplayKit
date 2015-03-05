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

#import "ScreenfulCellNode.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import "SlowNode.h"

@interface ScreenfulCellNode ()
@property(nonatomic, strong) ASTextNode *numberNode;
@property(nonatomic, strong) SlowNode *slowNode;
@end

@implementation ScreenfulCellNode

- (instancetype)init
{
  self = [super init];
  if (self) {
    _numberNode = [ASTextNode new];
    _slowNode = [SlowNode new];
    [self addSubnode:_numberNode];
    [self addSubnode:_slowNode];
  }
  return self;
}

- (void)updateIndex:(NSString *)index {
  self.numberNode.attributedString = [[NSAttributedString alloc] initWithString:index];
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize {
  CGSize cellSize = [UIScreen mainScreen].bounds.size;
  [self.numberNode measure:cellSize];
  return cellSize;
}

- (void)layout {
  [super layout];
  
  CGPoint origin = CGPointZero;
  origin.y = self.calculatedSize.height / 2.0f - (self.numberNode.calculatedSize.height / 2.0f);
  origin.x = self.calculatedSize.width / 2.0f - (self.numberNode.calculatedSize.width / 2.0f);
  self.numberNode.frame = CGRectMake(origin.x, origin.y, self.numberNode.calculatedSize.width, self.numberNode.calculatedSize.height);
  
  self.slowNode.frame = CGRectMake(0, 0, 100, 100);
}

- (void)displayWillStart {
  [super displayWillStart];
  NSLog(@"Screenful Cell Node display will start at index: %@", self.numberNode.attributedString);
}

- (void)subnodeDisplayDidFinish:(ASDisplayNode *)subnode {
  [super subnodeDisplayDidFinish:subnode];
  if (subnode == self.slowNode) {
//    NSLog(@"Slow node finished display at index: %@", self.numberNode.text);
  }
}

@end

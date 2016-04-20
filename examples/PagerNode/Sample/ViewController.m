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

#import "PageNode.h"

@interface ViewController () <ASPagerNodeDataSource>

- (ASPagerNode *)node;

@end

@implementation ViewController

- (instancetype)init
{
  if (!(self = [super initWithNode:[[ASPagerNode alloc] init]]))
    return nil;

  [self node].dataSource = self;
  
  self.title = @"Pages";

  return self;
}

- (ASPagerNode *)node
{
  return (ASPagerNode *)[super node];
}

#pragma mark - ASPagerNodeDataSource

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 5;
}

- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
{
  PageNode *page = [[PageNode alloc] init];
  page.backgroundColor = [UIColor blueColor];
  return page;
}

@end

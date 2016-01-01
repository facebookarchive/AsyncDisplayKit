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

#import "GradientTableNode.h"
#import "RandomCoreGraphicsNode.h"
#import "AppDelegate.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>

@interface GradientTableNode ()
{
  ASTableNode *_tableNode;
  CGSize _elementSize;
}

@end


@implementation GradientTableNode

- (instancetype)initWithElementSize:(CGSize)size
{
  if (!(self = [super init]))
    return nil;

  _elementSize = size;

  _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  [self addSubnode:_tableNode];
  
  return self;
}

- (void)didLoad
{
  [super didLoad];
  _tableNode.view.asyncDelegate = self;
  _tableNode.view.asyncDataSource = self;
  
  ASRangeTuningParameters rangeTuningParameters;
  rangeTuningParameters.leadingBufferScreenfuls = 1.0;
  rangeTuningParameters.trailingBufferScreenfuls = 0.5;
  [_tableNode.view setTuningParameters:rangeTuningParameters forRangeType:ASLayoutRangeTypeDisplay];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
  elementNode.preferredFrameSize = _elementSize;
  elementNode.indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:_pageNumber];
  return elementNode;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  [_tableNode.view reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)layout
{
  [super layout];
  
  _tableNode.frame = self.bounds;
}

@end

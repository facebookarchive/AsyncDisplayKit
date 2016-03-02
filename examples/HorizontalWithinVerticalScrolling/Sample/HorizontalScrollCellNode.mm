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

#import "HorizontalScrollCellNode.h"
#import "RandomCoreGraphicsNode.h"
#import "AppDelegate.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>

static const CGFloat kOuterPadding = 16.0f;
static const CGFloat kInnerPadding = 10.0f;

@interface HorizontalScrollCellNode ()
{
  ASCollectionNode *_collectionNode;
  CGSize _elementSize;
  ASDisplayNode *_divider;
}

@end


@implementation HorizontalScrollCellNode

- (instancetype)initWithElementSize:(CGSize)size
{
  if (!(self = [super init]))
    return nil;

  _elementSize = size;

  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.itemSize = _elementSize;
  flowLayout.minimumInteritemSpacing = kInnerPadding;
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
  [self addSubnode:_collectionNode];
  
  // hairline cell separator
  _divider = [[ASDisplayNode alloc] init];
  _divider.backgroundColor = [UIColor lightGrayColor];
  [self addSubnode:_divider];

  return self;
}

- (void)didLoad
{
  [super didLoad];
  _collectionNode.view.asyncDelegate = self;
  _collectionNode.view.asyncDataSource = self;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return 5;
}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{
    RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
    elementNode.preferredFrameSize = _elementSize;
    return elementNode;
  };
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _collectionNode.preferredFrameSize = CGSizeMake(self.bounds.size.width, _elementSize.height);
  
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
  insetSpec.insets = UIEdgeInsetsMake(kOuterPadding, 0.0, kOuterPadding, 0.0);
  insetSpec.child = _collectionNode;
  
  return insetSpec;
}

// With box model, you don't need to override this method, unless you want to add custom logic.
- (void)layout
{
  [super layout];
  
  _collectionNode.view.contentInset = UIEdgeInsetsMake(0.0, kOuterPadding, 0.0, kOuterPadding);
  
  // Manually layout the divider.
  CGFloat pixelHeight = 1.0f / [[UIScreen mainScreen] scale];
  _divider.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, pixelHeight);
}

@end

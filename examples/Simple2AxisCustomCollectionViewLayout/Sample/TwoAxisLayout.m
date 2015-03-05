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

#import "TwoAxisLayout.h"

#import <AsyncDisplayKit/ASCollectionView.h>

@interface TwoAxisLayout ()
@property(nonatomic, strong) NSArray *alllLayoutAttributes;
@end

// TODO: OK - it would be nice to run the entire layout logic when the data controller creates and sizes all the nodes
//   that way when la for elements in rect gets called the layout is aware of all the nodes --- batch insertions
//   are really making this difficult.
// The real problem is that at the time the first cell willDisplay, that's when the render range is determined and at that time not all nodes have been batched inserted yet!!!!!!!!!!!!!!!!! nothing should run until the batch insertion is finished!!
@implementation TwoAxisLayout

- (void)prepareLayout
{
  [super prepareLayout];
  if (![self laysOutAsyncCollectionView]) {
    return;
  }
  
  if ([self.collectionView numberOfSections] == 0) {
    return;
  }
  
  NSMutableArray *allLayoutAttributes = [@[] mutableCopy];
  for (NSInteger i = 0; i < [self.collectionView numberOfItemsInSection:0]; i++) {
    NSInteger row = floorf(i/10);
    CGPoint origin = CGPointZero;
    origin.y = row * [self screenSize].height;
    NSInteger column = i%10;
    origin.x = column * [self screenSize].width;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
    UICollectionViewLayoutAttributes *la = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    la.frame = CGRectMake(origin.x, origin.y, [self screenSize].width, [self screenSize].height);
    NSLog(@"%li frame: %@", (long)i, NSStringFromCGRect(la.frame));
    [allLayoutAttributes addObject:la];
  }
  self.alllLayoutAttributes = [allLayoutAttributes copy];
}

- (CGSize)collectionViewContentSize
{
  if (![self laysOutAsyncCollectionView]) {
    return CGSizeZero;
  }
  CGSize screenSize = [self screenSize];
  CGSize contentSize = CGSizeZero;
  contentSize.width = screenSize.width * [self numberOfScreenfulsWide];
  contentSize.height = screenSize.height * [self numberOfScreenfulsHigh];
  return contentSize;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
  if (![self laysOutAsyncCollectionView]) {
    return @[];
  }
  NSMutableArray *laForElementsInRect = [@[] mutableCopy];
  for (UICollectionViewLayoutAttributes *la in self.alllLayoutAttributes) {
    if (CGRectIntersectsRect(rect, la.frame)) {
      [laForElementsInRect addObject:la];
    }
  }
  return [laForElementsInRect copy];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (![self laysOutAsyncCollectionView]) {
    return nil;
  }
  if (indexPath.section > 0 || indexPath.item >= [self.alllLayoutAttributes count]) {
    return nil;
  }
  return self.alllLayoutAttributes[indexPath.item];
}

- (BOOL)laysOutAsyncCollectionView
{
  if ([self asyncCollectionView] != nil) {
    return YES;
  } else {
    return NO;
  }
}

- (ASCollectionView *)asyncCollectionView
{
  if ([self.collectionView isKindOfClass:[ASCollectionView class]]) {
    return (ASCollectionView *)self.collectionView;
  } else {
    return nil;
  }
}

- (NSInteger)numberOfScreenfulsWide {
  return 10;
}

- (NSInteger)numberOfScreenfulsHigh {
  return 10;
}

- (CGSize)screenSize {
  return [UIScreen mainScreen].bounds.size;
}

@end

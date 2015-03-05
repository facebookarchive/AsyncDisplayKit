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
#import <AsyncDisplayKit/ASAssert.h>

#import "TwoAxisLayout.h"
#import "ScreenfulCellNode.h"


@interface ViewController () <ASCollectionViewDataSource, ASCollectionViewDelegate>
@property (nonatomic, strong) ASCollectionView *asyncCollectionView;
@end


@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  TwoAxisLayout *layout = [TwoAxisLayout new];
  self.asyncCollectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero
                                                collectionViewLayout:layout asyncDataFetching:NO];
  self.asyncCollectionView.asyncDataSource = self;
  self.asyncCollectionView.asyncDelegate = self;
  
  [self.view addSubview:self.asyncCollectionView];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  self.asyncCollectionView.frame = self.view.bounds;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return 10 * 10;
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath {
  ScreenfulCellNode *node = [ScreenfulCellNode new];
  node.backgroundColor = [UIColor whiteColor];
  node.borderColor = [UIColor blackColor].CGColor;
  node.borderWidth = 4.0f;
  [node updateIndex:[NSString stringWithFormat:@"%li", (long)indexPath.item]];
  return node;
}

- (void)collectionViewLockDataSource:(ASCollectionView *)collectionView { }

- (void)collectionViewUnlockDataSource:(ASCollectionView *)collectionView { }

@end

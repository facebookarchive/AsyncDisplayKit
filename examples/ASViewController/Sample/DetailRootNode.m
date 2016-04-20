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

#import "DetailRootNode.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "DetailCellNode.h"

static const NSInteger kImageHeight = 200;

@interface DetailRootNode () <ASCollectionViewDataSource, ASCollectionViewDelegate>
@property (nonatomic, copy) NSString *imageCategory;
@property (nonatomic, strong) ASCollectionNode *collectionNode;
@end

@implementation DetailRootNode

#pragma mark - Lifecycle

- (instancetype)initWithImageCategory:(NSString *)imageCategory
{
    self = [super init];
    if (self == nil) { return self; }
    
    _imageCategory = imageCategory;

    // Create ASCollectionView. We don't have to add it explicitly as subnode as we will set usesImplicitHierarchyManagement to YES
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
    _collectionNode.delegate = self;
    _collectionNode.dataSource = self;
    _collectionNode.backgroundColor = [UIColor whiteColor];
    
    // Enable usesImplicitHierarchyManagement so the first time the layout pass of the node is happening all nodes that are referenced
    // in layouts within layoutSpecThatFits: will be added automatically
    self.usesImplicitHierarchyManagement = YES;
    
    return self;
}

- (void)dealloc
{
    _collectionNode.delegate = nil;
    _collectionNode.dataSource = nil;
}

#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    self.collectionNode.position = CGPointZero;
    self.collectionNode.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(constrainedSize.max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[self.collectionNode]];
}

#pragma mark - ASCollectionDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 10;
}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *imageCategory = self.imageCategory;
    return ^{
        DetailCellNode *node = [[DetailCellNode alloc] init];
        node.row = indexPath.row;
        node.imageCategory = imageCategory;
        return node;
    };
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize imageSize = CGSizeMake(CGRectGetWidth(collectionView.frame), kImageHeight);
    return ASSizeRangeMake(imageSize, imageSize);
}

@end

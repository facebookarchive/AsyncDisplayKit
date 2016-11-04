//
//  ViewController.m
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "MosaicCollectionViewLayout.h"
#import "ImageCellNode.h"

static NSUInteger kNumberOfImages = 14;

@interface ViewController () <ASCollectionDataSource, ASCollectionDelegate>
{
  NSMutableArray<NSMutableArray<UIImage *> *> *_sections;
  ASCollectionNode *_collectionNode;
  MosaicCollectionViewLayoutInspector *_layoutInspector;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  MosaicCollectionViewLayout *layout = [[MosaicCollectionViewLayout alloc] init];
  layout.numberOfColumns = 2;
  layout.headerHeight = 44.0;
  
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
  _collectionNode.dataSource = self;
  _collectionNode.delegate = self;
  _collectionNode.backgroundColor = [UIColor whiteColor];
  
  _layoutInspector = [[MosaicCollectionViewLayoutInspector alloc] init];

  if (!(self = [super initWithNode:_collectionNode]))
    return nil;
  
  _sections = [NSMutableArray array];
  [_sections addObject:[NSMutableArray array]];
  for (NSUInteger idx = 0, section = 0; idx < kNumberOfImages; idx++) {
    NSString *name = [NSString stringWithFormat:@"image_%lu.jpg", (unsigned long)idx];
    [_sections[section] addObject:[UIImage imageNamed:name]];
    if ((idx + 1) % 5 == 0 && idx < kNumberOfImages - 1) {
      section++;
      [_sections addObject:[NSMutableArray array]];
    }
  }
  
  [_collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _collectionNode.view.layoutInspector = _layoutInspector;
}

#pragma mark - ASCollectionNode data source.

- (ASCollectionData *)dataForCollectionNode:(ASCollectionNode *)collectionNode
{
  ASCollectionData *data = [collectionNode createNewData];
  for (NSArray *section in _sections) {
    [data addSectionWithIdentifier:[NSString stringWithFormat:@"Section %p", section] block:^(ASCollectionData * _Nonnull data) {
      for (UIImage *image in section) {
        [data addItemWithIdentifier:[NSString stringWithFormat:@"Item %p", image] nodeBlock:^ASCellNode * _Nonnull{
          return [[ImageCellNode alloc] initWithImage:image];
        }];
      }
    }];
  }
  return data;
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSDictionary *textAttributes = @{
      NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
      NSForegroundColorAttributeName: [UIColor grayColor]
  };
  UIEdgeInsets textInsets = UIEdgeInsetsMake(11.0, 0, 11.0, 0);
  ASTextCellNode *textCellNode = [[ASTextCellNode alloc] initWithAttributes:textAttributes insets:textInsets];
  textCellNode.text = [NSString stringWithFormat:@"Section %zd", indexPath.section + 1];
  return textCellNode;
}

- (CGSize)collectionView:(ASCollectionNode *)collectionNode layout:(UICollectionViewLayout *)collectionViewLayout originalItemSizeAtIndexPath:(NSIndexPath *)indexPath
{
  return [(UIImage *)_sections[indexPath.section][indexPath.item] size];
}

@end

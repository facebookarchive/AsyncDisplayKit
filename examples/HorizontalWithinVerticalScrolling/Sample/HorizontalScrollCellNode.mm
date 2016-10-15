//
//  HorizontalScrollCellNode.mm
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

#pragma mark - Lifecycle

- (instancetype)initWithElementSize:(CGSize)size
{
  if (!(self = [super init]))
    return nil;

  _elementSize = size;

  // the containing table uses -nodeForRowAtIndexPath (rather than -nodeBlockForRowAtIndexPath),
  // so this init method will always be run on the main thread (thus it is safe to do UIKit things).
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.itemSize = _elementSize;
  flowLayout.minimumInteritemSpacing = kInnerPadding;
  
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
  _collectionNode.delegate = self;
  _collectionNode.dataSource = self;
  [self addSubnode:_collectionNode];
  
  // hairline cell separator
  _divider = [[ASDisplayNode alloc] init];
  _divider.backgroundColor = [UIColor lightGrayColor];
  [self addSubnode:_divider];

  return self;
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

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGSize collectionNodeSize = CGSizeMake(constrainedSize.max.width, _elementSize.height);
  _collectionNode.style.preferredSize = collectionNodeSize;
  
  ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
  insetSpec.insets = UIEdgeInsetsMake(kOuterPadding, 0.0, kOuterPadding, 0.0);
  insetSpec.child = _collectionNode;
  
  return insetSpec;
}

#pragma mark - ASCollectionNode

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return 5;
}

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  CGSize elementSize = _elementSize;
  
  return ^{
    RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
    elementNode.style.preferredSize = elementSize;
    return elementNode;
  };
}

@end

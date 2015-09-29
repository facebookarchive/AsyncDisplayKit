//
//  ASCollectionViewFlowLayoutInspector.m
//  Pods
//
//  Created by Levi McCallum on 9/29/15.
//
//

#import "ASCollectionViewFlowLayoutInspector.h"

#import "ASCollectionView.h"

@implementation ASCollectionViewFlowLayoutInspector

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  // TODO: Implement some heuristic that follows the width/height constraints of header and footer supplementary views
  return ASSizeRangeMake(CGSizeZero, CGSizeMake(FLT_MAX, FLT_MAX));
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind {
  return self.collectionView.numberOfSections;
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryViewsOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  NSUInteger count = 0;
  if (self.layout.headerReferenceSize.width > 0 || self.layout.headerReferenceSize.height > 0) {
    count++;
  }
  if (self.layout.footerReferenceSize.width > 0 || self.layout.footerReferenceSize.height > 0) {
    count++;
  }
  return count;
}

@end

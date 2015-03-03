//  Copyright 2004-present Facebook. All Rights Reserved.

#import <AsyncDisplayKit/ASFlowLayoutController.h>

@interface ASCollectionViewLayoutController : ASFlowLayoutController

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection layout:(UICollectionViewLayout *)layout;

@end

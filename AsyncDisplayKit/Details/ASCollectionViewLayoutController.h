//  Copyright 2004-present Facebook. All Rights Reserved.

#import <AsyncDisplayKit/ASFlowLayoutController.h>

@interface ASCollectionViewLayoutController : ASFlowLayoutController

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;

- (instancetype)initWithLayout:(UICollectionViewLayout *)layout;

@end

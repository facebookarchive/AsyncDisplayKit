//
//  ASCollectionViewLayout.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/21/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionNode;

AS_SUBCLASSING_RESTRICTED
@interface ASCollectionViewLayout : UICollectionViewLayout

@property (nonatomic, weak) ASCollectionNode *collectionNode;

@end

NS_ASSUME_NONNULL_END

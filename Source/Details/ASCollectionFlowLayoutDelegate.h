//
//  ASCollectionFlowLayoutDelegate.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/2/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutDelegate.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED

@interface ASCollectionFlowLayoutDelegate : NSObject <ASCollectionLayoutDelegate>

- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections;

@end

NS_ASSUME_NONNULL_END

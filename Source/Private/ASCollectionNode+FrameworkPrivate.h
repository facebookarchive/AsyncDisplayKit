//
//  ASCollectionNode+FrameworkPrivate.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 23/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionNode ()

/**
 * Configure a new collection view layout that being set to either the collection node or its collection view.
 */
- (void)configureNewCollectionViewLayout:(UICollectionViewLayout *)layout;

@end

NS_ASSUME_NONNULL_END

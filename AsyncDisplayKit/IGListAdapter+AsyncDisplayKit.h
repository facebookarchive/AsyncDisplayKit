//
//  IGListAdapter+AsyncDisplayKit.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import <IGListKit/IGListKit.h>

@protocol ASListAdapter;

NS_ASSUME_NONNULL_BEGIN

@interface IGListAdapter (AsyncDisplayKit)

/**
 * An ASListAdapter that interfaces with this IGListAdapter.
 *
 * You can assign this to your collection node's listAdapter property,
 * e.g. `self.collectionNode.listAdapter = self.listAdapter.as_dataAdapter;`
 */
@property (nonatomic, strong, readonly) id<ASListAdapter> as_dataAdapter;

@end

NS_ASSUME_NONNULL_END

#endif // IG_LIST_KIT

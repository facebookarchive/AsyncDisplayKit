//
//  IGListAdapter+AsyncDisplayKit.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_IG_LIST_KIT

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionNode;

@interface IGListAdapter (AsyncDisplayKit)

/**
 * Connect this list adapter to the given collection node.
 *
 * @param collectionNode The collection node to drive with this list adapter.
 *
 * @note This method may only be called once per list adapter, 
 *   and it must be called on the main thread. -[UIViewController init]
 *   is a good place to call it. This method does not retain the collection node.
 */
- (void)setASDKCollectionNode:(ASCollectionNode *)collectionNode;

@end

NS_ASSUME_NONNULL_END

#endif // AS_IG_LIST_KIT

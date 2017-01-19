//
//  ASListAdapterImpl.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import <IGListKit/IGListKit.h>
#import "ASListAdapter.h"

/**
 * A default implementation of ASListAdapter, based on
 * IGListAdapter.
 */
__attribute((objc_subclassing_restricted))
@interface ASListAdapterImpl : NSObject <ASListAdapter>

- (instancetype)initWithIGListAdapter:(IGListAdapter *)listAdapter;

@end

#endif

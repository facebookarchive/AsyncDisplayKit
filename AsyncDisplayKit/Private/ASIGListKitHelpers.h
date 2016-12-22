//
//  ASIGListKitHelpers.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import <IGListKit/IGListKit.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface IGListAdapter (ASDKHelpers)

/**
 * Get the section controller at the given section. This is private right now but
 * maybe in the future it'll be public.
 */
- (IGListSectionController<ASIGListSectionType> *)as_sectionControllerAtSection:(NSInteger)section;

@end

#endif

//
//  ASIGListKitHelpers.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#if IG_LIST_KIT

#import "ASIGListKitHelpers.h"

@implementation IGListAdapter (ASDKHelpers)

- (IGListSectionController<ASIGListSectionType> *)as_sectionControllerAtSection:(NSInteger)section
{
  id object = [self objectAtSection:section];
  id<ASIGListSectionType> ctrl = [self sectionControllerForObject:object];
  ASDisplayNodeAssert([ctrl conformsToProtocol:@protocol(ASIGListSectionType)], @"Expected section controller to conform to %@. Controller: %@", NSStringFromProtocol(@protocol(ASIGListSectionType)), ctrl);
  return ctrl;
}

@end

#endif

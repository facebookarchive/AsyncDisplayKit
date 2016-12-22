//
//  RefreshingSectionControllerType.h
//  Sample
//
//  Created by Adlai Holler on 12/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol RefreshingSectionControllerType <IGListSectionType>

- (void)refreshContentWithCompletion:(nullable void(^)())completion;

@end

NS_ASSUME_NONNULL_END

//
//  ASViewWrapperNode.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 3/23/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASViewWrapperNode : ASDisplayNode

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock NS_DESIGNATED_INITIALIZER;

#pragma mark Unavailable

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

//
//  ASLayerWrapperNode.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 3/23/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASLayerWrapperNode : ASDisplayNode

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

//
//  ASVideoPlayerNode.h
//  AsyncDisplayKit
//
//  Created by Erekle on 5/6/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#if TARGET_OS_IOS
#import <AsyncDisplayKit/AsyncDisplayKit.h>
//#import <AsyncDisplayKit/ASThread.h>
//#import <AsyncDisplayKit/ASVideoNode.h>
//#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@class AVAsset;

NS_ASSUME_NONNULL_BEGIN

@interface ASVideoPlayerNode : ASDisplayNode

- (instancetype)initWithUrl:(NSURL*)url;
- (instancetype)initWithAsset:(AVAsset*)asset;
@end
NS_ASSUME_NONNULL_END
#endif

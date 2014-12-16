//  Copyright 2004-present Facebook. All Rights Reserved.

#import <AsyncDisplayKit/ASLayoutController.h>

typedef NS_ENUM(NSUInteger, ASFlowLayoutDirection) {
  ASFlowLayoutDirectionVertical,
  ASFlowLayoutDirectionHorizontal,
};

/**
 * The controller for flow layout.
 */
@interface ASFlowLayoutController : NSObject <ASLayoutController>

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters;

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection;

@end

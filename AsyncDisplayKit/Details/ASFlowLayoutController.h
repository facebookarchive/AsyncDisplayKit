//  Copyright 2004-present Facebook. All Rights Reserved.

#import <AsyncDisplayKit/ASLayoutController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>


typedef NS_ENUM(NSUInteger, ASFlowLayoutDirection) {
  ASFlowLayoutDirectionVertical,
  ASFlowLayoutDirectionHorizontal,
};

/**
 * The controller for flow layout.
 */
@interface ASFlowLayoutController : NSObject <ASLayoutController>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRange:(ASLayoutRange)range;

- (ASRangeTuningParameters)tuningParametersForRange:(ASLayoutRange)range;

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection;

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters ASDISPLAYNODE_DEPRECATED;

@end

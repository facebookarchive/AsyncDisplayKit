//
//  Node.m
//  Sample
//
//  Created by Gautham Badhrinathan on 8/23/16.
//  Copyright © 2016 Facebook Inc. All rights reserved.
//

#if __has_include(<ComponentKit/ComponentKit.h>)

#import "Node.h"

#import <AsyncDisplayKit/ASComponentHostingNode.h>
#import <ComponentKit/ComponentKit.h>

#import "Component.h"

@interface Node () <CKComponentProvider, ASComponentHostingNodeDelegate>

@property (nonatomic, strong, readonly) ASComponentHostingNode *hostingNode;

@end

@implementation Node

- (instancetype)init
{
  if (self = [super init]) {
    _hostingNode =
    [[ASComponentHostingNode alloc]
     initWithComponentProvider:[self class]
     sizeRangeProvider:
     [CKComponentFlexibleSizeRangeProvider
      providerWithFlexibility:CKComponentSizeRangeFlexibleWidthAndHeight]];
    _hostingNode.delegate = self;
    [self addSubnode:_hostingNode];
  }
  return self;
}

- (void)layout
{
  [super layout];

  CGSize hostingNodeSize = [_hostingNode measure:self.bounds.size];
  _hostingNode.frame = {
    .origin = {
      .x = (CGRectGetWidth(self.bounds) - hostingNodeSize.width) / 2,
      .y = (CGRectGetHeight(self.bounds) - hostingNodeSize.height) / 2,
    },
    .size = hostingNodeSize,
  };
}

+ (CKComponent *)componentForModel:(id<NSObject>)model context:(id<NSObject>)context
{
  return [Component new];
}

- (void)componentHostingNodeDidInvalidateSize:(ASComponentHostingNode *)hostingNode
{
  [self setNeedsLayout];
}

@end

#endif

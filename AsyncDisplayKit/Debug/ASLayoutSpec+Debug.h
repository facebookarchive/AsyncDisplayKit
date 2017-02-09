//
//  ASLayoutSpec+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/20/16.
//
//

#pragma once
#import <AsyncDisplayKit/ASControlNode.h>

#define ASLAYOUTSPEC_DEBUG 1

#if ASLAYOUTSPEC_DEBUG

@class ASLayoutSpec;

@interface ASLayoutSpecVisualizerNode : ASControlNode

@property (nonatomic, strong) ASLayoutSpec *layoutSpec;

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec;

@end

#endif


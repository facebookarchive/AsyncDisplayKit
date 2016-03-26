//
//  ASLayoutSpec+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/20/16.
//
//

#import "ASLayoutSpec.h"
#import "ASControlNode.h"

@interface ASLayoutSpec (Debugging2)   // FIXME: the ASCII art ASLayout stuff already claimed the Debugging category name

+ (BOOL)shouldVisualizeLayoutSpecs2;
+ (void)setShouldVisualizeLayoutSpecs2:(BOOL)shouldVisualizeLayoutSpecs;

@end

@interface ASLayoutSpecVisualizerNode : ASControlNode

@property (nonatomic, strong) ASLayoutSpec *layoutSpec;

- (instancetype)initWithLayoutSpec:(ASLayoutSpec *)layoutSpec;

@end


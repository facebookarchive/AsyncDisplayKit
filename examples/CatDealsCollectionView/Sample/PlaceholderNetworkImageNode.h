//
//  PlacholderNetworkImageNode.h
//  Sample
//
//  Created by Samuel Stow on 1/14/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface PlaceholderNetworkImageNode : ASNetworkImageNode

@property (nonatomic, strong) UIImage *placeholderImageOverride;

@end

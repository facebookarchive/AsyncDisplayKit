//
//  ASImageNode+Private.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 12/3/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#pragma mark - ASImageNode

#import "ASImageNode.h"

@interface ASImageNode (Private)

/*
 * Set the image property of the ASImageNode. Subclasses like ASNetworkImageNode do not allow setting the
 * image property directly and throw an assertion. There still needs to be a way for subclasses of
 * ASNetworkImageNode to set the image.
 */
- (void)__setImage:(UIImage *)image;

@end

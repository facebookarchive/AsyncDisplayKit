//
//  ASImageContainerProtocolCategories.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/18/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASImageContainerProtocolCategories.h"

@implementation UIImage (ASImageContainerProtocol)

- (UIImage *)asdk_image
{
    return self;
}

- (NSData *)asdk_animatedImageData
{
    return nil;
}

@end

@implementation NSData (ASImageContainerProtocol)

- (UIImage *)asdk_image
{
    return nil;
}

- (NSData *)asdk_animatedImageData
{
    return self;
}

@end

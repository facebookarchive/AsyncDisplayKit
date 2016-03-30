//
//  ASImageContainerProtocolCategories.m
//  Pods
//
//  Created by Garrett Moon on 3/18/16.
//
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

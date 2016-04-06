//
//  ASImageNode+AnimatedImage.h
//  Pods
//
//  Created by Garrett Moon on 3/22/16.
//
//

#import "ASImageNode.h"

#import "ASImageProtocols.h"

@interface ASImageNode ()

@property (atomic, assign) BOOL animatedImagePaused;

@end

@interface ASImageNode (AnimatedImage)

@property (nullable, atomic, strong) id <ASAnimatedImageProtocol> animatedImage;

@end

//
//  ASImageNode+AnimatedImage.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/22/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASImageNode.h"
#import "ASImageProtocols.h"

@interface ASImageNode ()
@property (atomic, assign) BOOL animatedImagePaused;
@property (nullable, atomic, strong) id <ASAnimatedImageProtocol> animatedImage;
@end

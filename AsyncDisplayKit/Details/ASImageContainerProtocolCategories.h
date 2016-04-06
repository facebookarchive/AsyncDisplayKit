//
//  ASImageContainerProtocolCategories.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/18/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ASImageProtocols.h"

@interface UIImage (ASImageContainerProtocol) <ASImageContainerProtocol>

@end

@interface NSData (ASImageContainerProtocol) <ASImageContainerProtocol>

@end

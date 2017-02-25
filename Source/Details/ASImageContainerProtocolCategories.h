//
//  ASImageContainerProtocolCategories.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 3/18/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASImageProtocols.h>

@interface UIImage (ASImageContainerProtocol) <ASImageContainerProtocol>

@end

@interface NSData (ASImageContainerProtocol) <ASImageContainerProtocol>

@end

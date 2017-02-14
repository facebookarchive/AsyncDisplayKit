//
//  ASResponderChainEnumerator.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/13/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIResponder.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASResponderChainEnumerator : NSEnumerator

- (instancetype)initWithResponder:(UIResponder *)responder;

@end

@interface UIResponder (ASResponderChainEnumerator)

- (ASResponderChainEnumerator *)asdk_responderChainEnumerator;

@end


NS_ASSUME_NONNULL_END

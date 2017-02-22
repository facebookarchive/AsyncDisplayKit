//
//  ASTextFieldView.h
//  AsyncDisplayKit
//
//  Created by Kyle Shank on 2/14/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#ifndef ASTextFieldView_h
#define ASTextFieldView_h

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASTextFieldView : UITextField
@property (nonatomic, assign) UIEdgeInsets textContainerInset;
@end

NS_ASSUME_NONNULL_END

#endif /* ASTextFieldView_h */

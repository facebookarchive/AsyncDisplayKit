//
//  ASTextFieldNode.h
//  AsyncDisplayKit
//
//  Created by Kyle Shank on 2/14/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#ifndef ASTextFieldNode_h
#define ASTextFieldNode_h

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASControlNode.h>
#import "ASTextFieldView.h"

@interface ASTextFieldNode : ASDisplayNode <UITextInputTraits>
@property (nonatomic, retain) ASDisplayNode* textFieldNode;
@property (nonatomic, retain) ASTextFieldView* textField;

@property (nonatomic, assign) NSString* text;
@property (nonatomic, assign) NSString* attributedText;
@property (nonatomic, assign) NSString* attributedPlaceholder;
@property (nonatomic, assign) UIFont* font;
@property (nonatomic, assign) UIColor* textColor;

@property (nonatomic, assign) UIEdgeInsets textContainerInset;
@end

#endif /* ASTextFieldNode_h */

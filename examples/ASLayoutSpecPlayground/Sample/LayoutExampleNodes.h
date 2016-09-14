//
//  LayoutExampleNodes.h
//  Sample
//
//  Created by Hannah Troisi on 9/13/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface LayoutExampleNode : ASDisplayNode

- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size;

@end

@interface HorizontalStackWithSpacer : LayoutExampleNode

@property (nonatomic, strong) ASTextNode *usernameTextNode;
@property (nonatomic, strong) ASTextNode *postTimeTextNode;

@end

@interface PhotoWithInsetTextOverlay : LayoutExampleNode

@property (nonatomic, strong) ASNetworkImageNode *avatarImageNode;
@property (nonatomic, strong) ASTextNode *usernameTextNode;

@end

@interface PhotoWithOutsetIconOverlay : LayoutExampleNode

@property (nonatomic, strong) ASNetworkImageNode *photoImageNode;
@property (nonatomic, strong) ASNetworkImageNode *plusIconImageNode;

@end
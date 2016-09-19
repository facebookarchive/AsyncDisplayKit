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

@property (nonatomic, strong) ASTextNode *usernameNode;
@property (nonatomic, strong) ASTextNode *postLocationNode;
@property (nonatomic, strong) ASTextNode *postTimeNode;

@end

@interface PhotoWithInsetTextOverlay : LayoutExampleNode

@property (nonatomic, strong) ASNetworkImageNode *photoNode;
@property (nonatomic, strong) ASTextNode *titleNode;

@end

@interface PhotoWithOutsetIconOverlay : LayoutExampleNode

@property (nonatomic, strong) ASNetworkImageNode *photoNode;
@property (nonatomic, strong) ASNetworkImageNode *iconNode;

@end

@interface FlexibleSeparatorSurroundingContent : LayoutExampleNode

@property (nonatomic, strong) ASImageNode *topSeparator;
@property (nonatomic, strong) ASImageNode *bottomSeparator;
@property (nonatomic, strong) ASTextNode *textNode;

@end

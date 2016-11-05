//
//  LayoutExampleNodes.h
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface LayoutExampleNode : ASDisplayNode

+ (NSString *)title;
+ (NSString *)descriptionTitle;

- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size;

@end

@interface HeaderWithRightAndLeftItems : LayoutExampleNode

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

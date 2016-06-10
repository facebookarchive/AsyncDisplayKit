//
//  CommentsNode.m
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

#import "CommentsNode.h"
#import "TextStyles.h"

@interface CommentsNode ()
@property (nonatomic, strong) ASImageNode *iconNode;
@property (nonatomic, strong) ASTextNode *countNode;
@property (nonatomic, assign) NSInteger commentsCount;
@end

@implementation CommentsNode

- (instancetype)initWithCommentsCount:(NSInteger)comentsCount
{
    self = [super init];
    if (self) {
        _commentsCount = comentsCount;
        
        _iconNode = [[ASImageNode alloc] init];
        _iconNode.image = [UIImage imageNamed:@"icon_comment.png"];
        [self addSubnode:_iconNode];
        
        _countNode = [[ASTextNode alloc] init];
        if (_commentsCount > 0) {
           _countNode.attributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%zd", _commentsCount] attributes:[TextStyles cellControlStyle]];
        }
        [self addSubnode:_countNode];
        
        // make it tappable easily
        self.hitTestSlop = UIEdgeInsetsMake(-10, -10, -10, -10);
    }
    
    return self;
    
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStackLayoutSpec *mainStack =  [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:6.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[self.iconNode, self.countNode]];
    
    // set sizeRange to make width fixed to 60
    ASRelativeSize min = ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(60.0), ASRelativeDimensionMakeWithPoints(0.0));
    ASRelativeSize max = ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(60.0), ASRelativeDimensionMakeWithPoints(40.0));
    mainStack.sizeRange = ASRelativeSizeRangeMake(min,max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[mainStack]];
}

@end

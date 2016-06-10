//
//  LikesNode.m
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

#import "LikesNode.h"
#import "TextStyles.h"

@interface LikesNode ()
@property (nonatomic, strong) ASImageNode *iconNode;
@property (nonatomic, strong) ASTextNode *countNode;
@property (nonatomic, assign) NSInteger likesCount;
@property (nonatomic, assign) BOOL liked;
@end

@implementation LikesNode

- (instancetype)initWithLikesCount:(NSInteger)likesCount
{
    self = [super init];
    if (self) {
        _likesCount = likesCount;
        _liked = (_likesCount > 0) ? [LikesNode getYesOrNo] : NO;
        
        _iconNode = [[ASImageNode alloc] init];
        _iconNode.image = (_liked) ? [UIImage imageNamed:@"icon_liked.png"] : [UIImage imageNamed:@"icon_like.png"];
        [self addSubnode:_iconNode];
        
        _countNode = [[ASTextNode alloc] init];
        if (_likesCount > 0) {
            
            NSDictionary *attributes = _liked ? [TextStyles cellControlColoredStyle] : [TextStyles cellControlStyle];
            _countNode.attributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", (long)_likesCount] attributes:attributes];
            
        }
        [self addSubnode:_countNode];
        
        // make it tappable easily
        self.hitTestSlop = UIEdgeInsetsMake(-10, -10, -10, -10);
    }
    
    return self;
    
}

+ (BOOL)getYesOrNo
{
    int tmp = (arc4random() % 30)+1;
    if (tmp % 5 == 0) {
        return YES;
    }
    return NO;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStackLayoutSpec *mainStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:6.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[_iconNode, _countNode]];
    
    // set sizeRange to make width fixed to 60
    ASRelativeSize min = ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(60.0), ASRelativeDimensionMakeWithPoints(0.0));
    ASRelativeSize max = ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(60.0), ASRelativeDimensionMakeWithPoints(40.0));
    mainStack.sizeRange = ASRelativeSizeRangeMake(min, max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[mainStack]];
}

@end

/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "CommentsNode.h"
#import "TextStyles.h"

@implementation CommentsNode

- (instancetype)initWithCommentsCount:(NSInteger)comentsCount {
    
    self = [super init];
    
    if(self) {
        
        _comentsCount = comentsCount;
        
        _iconNode = [[ASImageNode alloc] init];
        _iconNode.image = [UIImage imageNamed:@"icon_comment.png"];
        [self addSubnode:_iconNode];
        
        _countNode = [[ASTextNode alloc] init];
        if(_comentsCount > 0) {
            
           _countNode.attributedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", (long)_comentsCount] attributes:[TextStyles cellControlStyle]];
            
        }
        
        [self addSubnode:_countNode];
        
        // make it tappable easily
        self.hitTestSlop = UIEdgeInsetsMake(-10, -10, -10, -10);
        
    }
    
    return self;
    
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize {
    
    ASStackLayoutSpec *mainStack =  [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:6.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[_iconNode, _countNode]];
    
    // set sizeRange to make width fixed to 60
    mainStack.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMake(
                                                                     ASRelativeDimensionMakeWithPoints(60.0),
                                                                     ASRelativeDimensionMakeWithPoints(0.0)
                                                                     ), ASRelativeSizeMake(
                                                                                           ASRelativeDimensionMakeWithPoints(60.0),
                                                                                           ASRelativeDimensionMakeWithPoints(40.0)
                                                                                           ));
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[mainStack]];
    
}


@end

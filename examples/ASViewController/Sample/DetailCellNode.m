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

#import "DetailCellNode.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@implementation DetailCellNode

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _imageNode = [ASNetworkImageNode new];
    _imageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
    [self addSubnode:_imageNode];
    
    return self;
}


#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStaticLayoutSpec *staticSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[self.imageNode]];
    self.imageNode.position = CGPointZero;
    self.imageNode.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(constrainedSize.max);
    return staticSpec;
}

- (void)fetchData
{
    [super fetchData];
    
    [self loadImage];
}


#pragma mark  - Image

- (NSURL *)imageURL
{
    CGSize imageSize = self.calculatedSize;
    NSString *imageURLString = [NSString stringWithFormat:@"http://lorempixel.com/%ld/%ld/%@/%ld", (NSInteger)imageSize.width, (NSInteger)imageSize.height, self.imageCategory, self.row];
    return [NSURL URLWithString:imageURLString];
}

- (void)loadImage
{
    self.imageNode.URL = self.imageURL;
}

@end

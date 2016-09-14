//
//  DetailCellNode.m
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

#import "DetailCellNode.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@implementation DetailCellNode

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _imageNode = [[ASNetworkImageNode alloc] init];
    _imageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
    [self addSubnode:_imageNode];
    
    return self;
}

#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    self.imageNode.position = CGPointZero;
    self.imageNode.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(constrainedSize.max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[self.imageNode]];
}

- (void)layoutDidFinish
{
    [super layoutDidFinish];
    
    // In general set URL of ASNetworkImageNode as soon as possible. Ideally in init or a
    // view model setter method.
    // In this case as we need to know the size of the node the url is set in layoutDidFinish so
    // we have the calculatedSize available
    self.imageNode.URL = [self imageURL];
}

#pragma mark  - Image

- (NSURL *)imageURL
{
    CGSize imageSize = self.calculatedSize;
    NSString *imageURLString = [NSString stringWithFormat:@"http://lorempixel.com/%ld/%ld/%@/%ld", (NSInteger)imageSize.width, (NSInteger)imageSize.height, self.imageCategory, self.row];
    return [NSURL URLWithString:imageURLString];
}

@end

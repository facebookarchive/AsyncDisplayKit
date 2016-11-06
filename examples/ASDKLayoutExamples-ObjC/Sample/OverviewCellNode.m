//
//  OverviewCellNode.m
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

#import "OverviewCellNode.h"
#import "LayoutExampleNodes.h"
#import "Utilities.h"

@interface OverviewCellNode ()
@property (nonatomic, strong) ASTextNode *titleNode;
@property (nonatomic, strong) ASTextNode *descriptionNode;
@end

@implementation OverviewCellNode

- (instancetype)initWithLayoutExampleClass:(Class)layoutExampleClass
{
    self = [super init];
    if (self) {
      self.automaticallyManagesSubnodes = YES;
      
      _layoutExampleClass = layoutExampleClass;
      
      _titleNode = [[ASTextNode alloc] init];
      _titleNode.attributedText = [NSAttributedString attributedStringWithString:[layoutExampleClass title]
                                                                  fontSize:16
                                                                     color:[UIColor blackColor]];
  
      _descriptionNode = [[ASTextNode alloc] init];
      _descriptionNode.attributedText = [NSAttributedString attributedStringWithString:[layoutExampleClass descriptionTitle]
                                                                              fontSize:12
                                                                                 color:[UIColor lightGrayColor]];
   }
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
    verticalStackSpec.alignItems = ASStackLayoutAlignItemsStart;
    verticalStackSpec.spacing = 5.0;
    verticalStackSpec.children = @[self.titleNode, self.descriptionNode];
    
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 16, 10, 10) child:verticalStackSpec];
}

@end

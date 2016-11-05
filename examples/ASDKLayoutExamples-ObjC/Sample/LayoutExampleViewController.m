//
//  LayoutExampleViewController.m
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

#import "LayoutExampleViewController.h"
#import "LayoutExampleNodes.h"

@interface LayoutExampleViewController ()
@property (nonatomic, strong) LayoutExampleNode *customNode;
@end

@implementation LayoutExampleViewController

- (instancetype)initWithClass:(Class)class
{
  self = [super initWithNode:[ASDisplayNode new]];
  
  if (self) {
    _customNode = [class new];
    [self.node addSubnode:_customNode];
    
    __weak __typeof(self) weakself = self;
    if ([class isEqual:[HeaderWithRightAndLeftItems class]] || [class isEqual:[FlexibleSeparatorSurroundingContent class]]) {
      self.node.backgroundColor = [UIColor lightGrayColor];
      self.node.layoutSpecBlock = ^ASLayoutSpec*(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
        return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringY
                                                          sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY
                                                                  child:weakself.customNode];
      };
    } else {
      self.node.backgroundColor = [UIColor whiteColor];
      self.node.layoutSpecBlock = ^ASLayoutSpec*(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
        return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY
                                                          sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY
                                                                  child:weakself.customNode];
        };
    };
  }
  
  return self;
}

@end

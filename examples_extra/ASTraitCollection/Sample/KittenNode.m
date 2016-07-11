//
//  KittenNode.m
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

#import "KittenNode.h"
#import "OverrideViewController.h"

#import <AsyncDisplayKit/ASTraitCollection.h>

static const CGFloat kOuterPadding = 16.0f;
static const CGFloat kInnerPadding = 10.0f;

@interface KittenNode ()
{
  CGSize _kittenSize;
}

@end


@implementation KittenNode

// lorem ipsum text courtesy https://kittyipsum.com/ <3
+ (NSArray *)placeholders
{
  static NSArray *placeholders = nil;
  
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    placeholders = @[
                     @"Kitty ipsum dolor sit amet, purr sleep on your face lay down in your way biting, sniff tincidunt a etiam fluffy fur judging you stuck in a tree kittens.",
                     @"Lick tincidunt a biting eat the grass, egestas enim ut lick leap puking climb the curtains lick.",
                     @"Lick quis nunc toss the mousie vel, tortor pellentesque sunbathe orci turpis non tail flick suscipit sleep in the sink.",
                     @"Orci turpis litter box et stuck in a tree, egestas ac tempus et aliquam elit.",
                     @"Hairball iaculis dolor dolor neque, nibh adipiscing vehicula egestas dolor aliquam.",
                     @"Sunbathe fluffy fur tortor faucibus pharetra jump, enim jump on the table I don't like that food catnip toss the mousie scratched.",
                     @"Quis nunc nam sleep in the sink quis nunc purr faucibus, chase the red dot consectetur bat sagittis.",
                     @"Lick tail flick jump on the table stretching purr amet, rhoncus scratched jump on the table run.",
                     @"Suspendisse aliquam vulputate feed me sleep on your keyboard, rip the couch faucibus sleep on your keyboard tristique give me fish dolor.",
                     @"Rip the couch hiss attack your ankles biting pellentesque puking, enim suspendisse enim mauris a.",
                     @"Sollicitudin iaculis vestibulum toss the mousie biting attack your ankles, puking nunc jump adipiscing in viverra.",
                     @"Nam zzz amet neque, bat tincidunt a iaculis sniff hiss bibendum leap nibh.",
                     @"Chase the red dot enim puking chuf, tristique et egestas sniff sollicitudin pharetra enim ut mauris a.",
                     @"Sagittis scratched et lick, hairball leap attack adipiscing catnip tail flick iaculis lick.",
                     @"Neque neque sleep in the sink neque sleep on your face, climb the curtains chuf tail flick sniff tortor non.",
                     @"Ac etiam kittens claw toss the mousie jump, pellentesque rhoncus litter box give me fish adipiscing mauris a.",
                     @"Pharetra egestas sunbathe faucibus ac fluffy fur, hiss feed me give me fish accumsan.",
                     @"Tortor leap tristique accumsan rutrum sleep in the sink, amet sollicitudin adipiscing dolor chase the red dot.",
                     @"Knock over the lamp pharetra vehicula sleep on your face rhoncus, jump elit cras nec quis quis nunc nam.",
                     @"Sollicitudin feed me et ac in viverra catnip, nunc eat I don't like that food iaculis give me fish.",
                     ];
  });
  
  return placeholders;
}

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  _kittenSize = CGSizeMake(100,100);
  
  // kitten image, with a solid background colour serving as placeholder
  _imageNode = [[ASNetworkImageNode alloc] init];
  _imageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
  _imageNode.preferredFrameSize = _kittenSize;
  [_imageNode addTarget:self action:@selector(imageTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  
  CGFloat scale = [UIScreen mainScreen].scale;
  _imageNode.URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://placekitten.com/%zd/%zd?image=%zd",
                                         (NSInteger)roundl(_kittenSize.width * scale),
                                         (NSInteger)roundl(_kittenSize.height * scale),
                                         (NSInteger)arc4random_uniform(20)]];
  [self addSubnode:_imageNode];
  
  // lorem ipsum text, plus some nice styling
  _textNode = [[ASTextNode alloc] init];
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:[self kittyIpsum]
                                                               attributes:[self textStyle]];
  _textNode.flexShrink = YES;
  _textNode.flexGrow = YES;
  [self addSubnode:_textNode];
  
  return self;
}

- (void)imageTapped:(id)sender
{
  if (self.imageTappedBlock) {
    self.imageTappedBlock();
  }
}

- (NSString *)kittyIpsum
{
  NSArray *placeholders = [KittenNode placeholders];
  u_int32_t ipsumCount = (u_int32_t)[placeholders count];
  u_int32_t location = arc4random_uniform(ipsumCount);
  u_int32_t length = arc4random_uniform(ipsumCount - location);
  
  NSMutableString *string = [placeholders[location] mutableCopy];
  for (u_int32_t i = location + 1; i < location + length; i++) {
    [string appendString:(i % 2 == 0) ? @"\n" : @"  "];
    [string appendString:placeholders[i]];
  }
  
  return string;
}

- (NSDictionary *)textStyle
{
  UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:12.0f];
  
  NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  style.paragraphSpacing = 0.5 * font.lineHeight;
  style.hyphenationFactor = 1.0;
  
  return @{ NSFontAttributeName: font,
            NSParagraphStyleAttributeName: style,
            ASTextNodeWordKerningAttributeName : @.5};
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *stackSpec = [[ASStackLayoutSpec alloc] init];
  stackSpec.spacing = kInnerPadding;
  [stackSpec setChildren:@[_imageNode, _textNode]];
  
  if (self.asyncTraitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
    _imageNode.alignSelf = ASStackLayoutAlignSelfStart;
    stackSpec.direction = ASStackLayoutDirectionHorizontal;
  } else {
    _imageNode.alignSelf = ASStackLayoutAlignSelfCenter;
    stackSpec.direction = ASStackLayoutDirectionVertical;
  }
  
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(kOuterPadding, kOuterPadding, kOuterPadding, kOuterPadding) child:stackSpec];
}

+ (void)defaultImageTappedAction:(ASViewController *)sourceViewController
{
  OverrideViewController *overrideVC = [[OverrideViewController alloc] init];
  
  __weak OverrideViewController *weakOverrideVC = overrideVC;
  overrideVC.overrideDisplayTraitsWithTraitCollection = ^(UITraitCollection *traitCollection) {
    ASTraitCollection *asyncTraitCollection = [ASTraitCollection traitCollectionWithDisplayScale:traitCollection.displayScale
                                                                              userInterfaceIdiom:traitCollection.userInterfaceIdiom
                                                                             horizontalSizeClass:UIUserInterfaceSizeClassCompact
                                                                               verticalSizeClass:UIUserInterfaceSizeClassCompact
                                                                            forceTouchCapability:traitCollection.forceTouchCapability
                                                                                   containerSize:weakOverrideVC.view.bounds.size];
    return asyncTraitCollection;
  };
  
  [sourceViewController presentViewController:overrideVC animated:YES completion:nil];
  overrideVC.closeBlock = ^{
    [sourceViewController dismissViewControllerAnimated:YES completion:nil];
  };
}

@end

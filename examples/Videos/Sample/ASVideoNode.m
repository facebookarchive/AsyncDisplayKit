//
//  ASVideoNode.m
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


#import "ASVideoNode.h"

@interface ASVideoNode ()
@property (nonatomic) AVPlayer *player;
@end

@implementation ASVideoNode

- (instancetype)initWithURL:(NSURL *)URL;
{
  return [self initWithURL:URL videoGravity:ASVideoGravityResizeAspect];
}

- (instancetype)initWithURL:(NSURL *)URL videoGravity:(ASVideoGravity)gravity;
{
  if (!(self = [super initWithLayerBlock:^CALayer *{
    AVPlayerLayer *layer = [[AVPlayerLayer alloc] init];
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:URL];
    
    layer.player = [[AVPlayer alloc] initWithPlayerItem:item];
    
    return layer;
  }])) { return nil; }
  
  self.gravity = gravity;
  
  return self;
}

- (void)setGravity:(ASVideoGravity)gravity;
{
  switch (gravity) {
    case ASVideoGravityResize:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResize;
      break;
    case ASVideoGravityResizeAspect:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspect;
      break;
    case ASVideoGravityResizeAspectFill:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspectFill;
      break;
    default:
      ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspect;
      break;
  }
}

- (ASVideoGravity)gravity;
{
  if ([((AVPlayerLayer *)self.layer).contentsGravity isEqualToString:AVLayerVideoGravityResize]) {
    return ASVideoGravityResize;
  }
  if ([((AVPlayerLayer *)self.layer).contentsGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
    return ASVideoGravityResizeAspectFill;
  }
  
  return ASVideoGravityResizeAspect;
}

- (void)play;
{
  [[((AVPlayerLayer *)self.layer) player] play];
}

- (void)pause;
{
  [[((AVPlayerLayer *)self.layer) player] pause];
}

@end

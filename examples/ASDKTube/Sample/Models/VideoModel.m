//
//  VideoModel.m
//  Sample
//
//  Created by Erekle on 5/14/16.
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

#import "VideoModel.h"

@implementation VideoModel
- (instancetype)init
{
  self = [super init];
  if (self) {
    NSString *videoUrlString = @"https://www.w3schools.com/html/mov_bbb.mp4";
    NSString *avatarUrlString = [NSString stringWithFormat:@"https://api.adorable.io/avatars/50/%@",[[NSProcessInfo processInfo] globallyUniqueString]];

    _title      = @"Demo title";
    _url        = [NSURL URLWithString:videoUrlString];
    _userName   = @"Random User";
    _avatarUrl  = [NSURL URLWithString:avatarUrlString];
  }

  return self;
}
@end

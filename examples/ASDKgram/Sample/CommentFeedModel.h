//
//  CommentFeedModel.h
//  Sample
//
//  Created by Hannah Troisi on 3/9/16.
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

#import "CommentModel.h"

@interface CommentFeedModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPhotoID:(NSString *)photoID NS_DESIGNATED_INITIALIZER;

- (NSUInteger)numberOfItemsInFeed;
- (CommentModel *)objectAtIndex:(NSUInteger)index;

- (NSUInteger)numberOfCommentsForPhoto;
- (BOOL)numberOfCommentsForPhotoExceedsInteger:(NSUInteger)number;
- (NSAttributedString *)viewAllCommentsAttributedString;

- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block;
- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block;

@end

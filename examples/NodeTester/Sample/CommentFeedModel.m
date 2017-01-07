//
//  CommentFeedModel.m
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

#import "CommentFeedModel.h"
#import "Utilities.h"

#define NUM_COMMENTS_TO_SHOW 3

#define fiveHundredPX_ENDPOINT_HOST      @"https://api.500px.com/v1/"
#define fiveHundredPX_ENDPOINT_COMMENTS  @"photos/4928401/comments"
#define fiveHundredPX_ENDPOINT_SEARCH    @"photos/search?geo="    //latitude,longitude,radius<units>
#define fiveHundredPX_ENDPOINT_USER      @"photos?user_id="
#define fiveHundredPX_CONSUMER_KEY_PARAM @"&consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC"

@implementation CommentFeedModel
{
  NSMutableArray *_comments;    // array of CommentModel objects
  
  NSString       *_photoID;
  NSString       *_urlString;
  NSUInteger     _currentPage;
  NSUInteger     _totalPages;
  NSUInteger     _totalItems;
  
  BOOL           _fetchPageInProgress;
  BOOL           _refreshFeedInProgress;
}

#pragma mark - Properties

- (NSMutableArray *)comments
{
  return _comments;
}

#pragma mark - Lifecycle

- (instancetype)initWithPhotoID:(NSString *)photoID
{
  self = [super init];
  
  if (self) {
    _photoID     = photoID;
    _currentPage = 0;
    _totalPages  = 0;
    _totalItems  = 0;
    _comments    = [[NSMutableArray alloc] init];
    _urlString   = [NSString stringWithFormat:@"https://api.500px.com/v1/photos/%@/comments?",photoID];
  }
  
  return self;
}


#pragma mark - Instance Methods

- (NSUInteger)numberOfItemsInFeed
{
  return [_comments count];
}

- (CommentModel *)objectAtIndex:(NSUInteger)index
{
  return [_comments objectAtIndex:index];
}

- (NSUInteger)numberOfCommentsForPhoto
{
  return _totalItems;
}

- (BOOL)numberOfCommentsForPhotoExceedsInteger:(NSUInteger)number
{
  return (_totalItems > number);
}

- (NSAttributedString *)viewAllCommentsAttributedString
{
  NSString *string               = [NSString stringWithFormat:@"View all %@ comments", [NSNumber numberWithUnsignedInteger:_totalItems]];
  NSAttributedString *attrString = [NSAttributedString attributedStringWithString:string fontSize:14 color:[UIColor lightGrayColor] firstWordColor:nil];
  return attrString;
}

- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block
{
  // only one fetch at a time
  if (_fetchPageInProgress) {
      return;
  } else {
    _fetchPageInProgress = YES;
    [self fetchPageWithCompletionBlock:block];
  }
}

- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block
{
  // only one fetch at a time
  if (_refreshFeedInProgress) {
    return;
  } else {
    _refreshFeedInProgress = YES;
    _currentPage = 0;
    
    // FIXME: blow away any other requests in progress
    
    [self fetchPageWithCompletionBlock:^(NSArray *newPhotos) {
      if (block) {
        block(newPhotos);
      }
      _refreshFeedInProgress = NO;
    } replaceData:YES];
  }
}

#pragma mark - Helper Methods
- (void)fetchPageWithCompletionBlock:(void (^)(NSArray *))block
{
  [self fetchPageWithCompletionBlock:block replaceData:NO];
}

- (void)fetchPageWithCompletionBlock:(void (^)(NSArray *))block replaceData:(BOOL)replaceData
{
  // early return if reached end of pages
  if (_totalPages) {
    if (_currentPage == _totalPages) {
      return;
    }
  }
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    NSMutableArray *newComments = [NSMutableArray array];
    
    NSUInteger nextPage = _currentPage + 1;
    
    NSString *urlAdditions = [NSString stringWithFormat:@"page=%lu", (unsigned long)nextPage];
    NSURL *url = [NSURL URLWithString:[_urlString stringByAppendingString:urlAdditions]];
    NSURLSession *session      = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
      
      if (data) {
        
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        
        if ([response isKindOfClass:[NSDictionary class]]) {
          
          _currentPage = [[response valueForKeyPath:@"current_page"] integerValue];
          _totalPages  = [[response valueForKeyPath:@"total_pages"] integerValue];
          _totalItems  = [[response valueForKeyPath:@"total_items"] integerValue];
          
          NSArray *comments = [response valueForKeyPath:@"comments"];
          
          if ([comments isKindOfClass:[NSArray class]]) {
            
            NSUInteger numComments = [comments count];
            if (numComments > NUM_COMMENTS_TO_SHOW) {
              comments = [comments subarrayWithRange:(NSRange){numComments-NUM_COMMENTS_TO_SHOW, NUM_COMMENTS_TO_SHOW}];
            }
            
            for (NSDictionary *commentDictionary in comments) {
              
              if ([response isKindOfClass:[NSDictionary class]]) {
                
                CommentModel *comment = [[CommentModel alloc] initWithDictionary:commentDictionary];
                
                if (comment) {
                  [newComments addObject:comment];
                }
              }
            }
          }
        }
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        _fetchPageInProgress = NO;
        if (replaceData) {
          _comments = [newComments mutableCopy];
        } else {
          [_comments addObjectsFromArray:newComments];
        }
        if (block) {
          block(newComments);
        }
      });
    }];
    [task resume];
  });
}

@end

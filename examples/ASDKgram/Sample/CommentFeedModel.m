//
//  CommentFeedModel.m
//  ASDKgram
//
//  Created by Hannah Troisi on 3/9/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "CommentFeedModel.h"
#import <UIKit/UIKit.h>
#import "Utilities.h"

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
  
    _urlString = [NSString stringWithFormat:@"https://api.500px.com/v1/photos/%@/comments?",photoID];
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
    
//    NSLog(@"Request COMMENTS: FAIL - fetch page already in progress");
    return;
    
  } else {
    
    _fetchPageInProgress = YES;
    
//    NSLog(@"Request COMMENTS: SUCCESS");
    [self fetchPageWithCompletionBlock:block];
  }
}

- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block
{
  // only one fetch at a time
  if (_refreshFeedInProgress) {
    
//    NSLog(@"Request Refresh COMMENTS: FAIL - refresh feed already in progress");
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
    
    @synchronized(self) {
      
      NSUInteger nextPage = _currentPage + 1;
      
      NSString *urlAdditions = [NSString stringWithFormat:@"page=%lu", (unsigned long)nextPage];
      NSURL *url = [NSURL URLWithString:[_urlString stringByAppendingString:urlAdditions]];
      
      NSData *data = [NSData dataWithContentsOfURL:url];
      
      if (data) {
        
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        
        if ([response isKindOfClass:[NSDictionary class]]) {
          
          _currentPage = [[response valueForKeyPath:@"current_page"] integerValue];
          _totalPages  = [[response valueForKeyPath:@"total_pages"] integerValue];
          _totalItems  = [[response valueForKeyPath:@"total_items"] integerValue];
          
          NSArray *comments = [response valueForKeyPath:@"comments"];
          
//          NSLog(@"Request Refresh COMMENTS: SUCCESS %@", comments);
          
          if ([comments isKindOfClass:[NSArray class]]) {
            
            NSUInteger numComments = [comments count];
            if (numComments > 3) {
              comments = [comments subarrayWithRange:(NSRange){numComments-3, 3}];
            }
            
            for (NSDictionary *commentDictionary in comments) {
              
              if ([response isKindOfClass:[NSDictionary class]]) {
                
                CommentModel *comment = [[CommentModel alloc] initWithDictionary:commentDictionary];
                
                // addObject: will crash with nil (NSArray, NSSet, NSDictionary, URLWithString - most foundation things)
                if (comment) {
                  [newComments addObject:comment];
                }
              }
            }
          }
        }
      }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      
      if (replaceData) {
        _comments = [newComments mutableCopy];
      } else {
        [_comments addObjectsFromArray:newComments];
      }
      
      if (block) {
        block(newComments);
      }
    });
    
    _fetchPageInProgress = NO;
    
  });
}

@end

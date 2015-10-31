//
//  ScreenNode.m
//  Sample
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ScreenNode.h"

@interface ScreenNode() <ASMultiplexImageNodeDataSource, ASMultiplexImageNodeDelegate, ASImageDownloaderProtocol>
@end

@implementation ScreenNode

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }

  // multiplex image node!
  // NB:  we're using a custom downloader with an artificial delay for this demo, but ASBasicImageDownloader works too!
  _imageNode = [[ASMultiplexImageNode alloc] initWithCache:nil downloader:self];
  _imageNode.dataSource = self;
  _imageNode.delegate = self;
  
  // placeholder colour
  _imageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
  
  // load low-quality images before high-quality images
  _imageNode.downloadsIntermediateImages = YES;
  
  // simple status label.  Synchronous to avoid flicker / placeholder state when updating.
  _buttonNode = [[ASButtonNode alloc] init];
  [_buttonNode addTarget:self action:@selector(reload) forControlEvents:ASControlNodeEventTouchUpInside];
  _buttonNode.titleNode.displaysAsynchronously = NO;
  
  [self addSubnode:_imageNode];
  [self addSubnode:_buttonNode];
  
  return self;
}

- (void)start
{
  [self setText:@"loading…"];
  _buttonNode.userInteractionEnabled = NO;
  _imageNode.imageIdentifiers = @[ @"best", @"medium", @"worst" ]; // go!
}

- (void)reload
{
  [self start];
  [_imageNode reloadImageIdentifierSources];
}

- (void)setText:(NSString *)text
{
  NSDictionary *attributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:22.0f]};
  NSAttributedString *string = [[NSAttributedString alloc] initWithString:text
                                                               attributes:attributes];
  [_buttonNode setAttributedTitle:string forState:ASButtonStateNormal];
  [self setNeedsLayout];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASRatioLayoutSpec *imagePlaceholder = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:1 child:_imageNode];
  
  ASStackLayoutSpec *verticalStack = [[ASStackLayoutSpec alloc] init];
  verticalStack.direction = ASStackLayoutDirectionVertical;
  verticalStack.spacing = 10;
  verticalStack.justifyContent = ASStackLayoutJustifyContentCenter;
  verticalStack.alignItems = ASStackLayoutAlignItemsCenter;
  verticalStack.children = @[imagePlaceholder, _buttonNode];
                                      
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 10, 10, 10) child:verticalStack];
}

#pragma mark -
#pragma mark ASMultiplexImageNode data source & delegate.

- (NSURL *)multiplexImageNode:(ASMultiplexImageNode *)imageNode URLForImageIdentifier:(id)imageIdentifier
{
  if ([imageIdentifier isEqualToString:@"worst"]) {
    return [NSURL URLWithString:@"https://raw.githubusercontent.com/facebook/AsyncDisplayKit/master/examples/Multiplex/worst.png"];
  }
  
  if ([imageIdentifier isEqualToString:@"medium"]) {
    return [NSURL URLWithString:@"https://raw.githubusercontent.com/facebook/AsyncDisplayKit/master/examples/Multiplex/medium.png"];
  }
  
  if ([imageIdentifier isEqualToString:@"best"]) {
    return [NSURL URLWithString:@"https://raw.githubusercontent.com/facebook/AsyncDisplayKit/master/examples/Multiplex/best.png"];
  }
  
  // unexpected identifier
  return nil;
}

- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode didFinishDownloadingImageWithIdentifier:(id)imageIdentifier error:(NSError *)error
{
  [self setText:[NSString stringWithFormat:@"loaded '%@'", imageIdentifier]];
  
  if ([imageIdentifier isEqualToString:@"best"]) {
    [self setText:[_buttonNode.titleNode.attributedString.string stringByAppendingString:@".  tap to reload"]];
    _buttonNode.userInteractionEnabled = YES;
  }
}


#pragma mark -
#pragma mark ASImageDownloaderProtocol.

- (id)downloadImageWithURL:(NSURL *)URL
             callbackQueue:(dispatch_queue_t)callbackQueue
     downloadProgressBlock:(void (^)(CGFloat progress))downloadProgressBlock
                completion:(void (^)(CGImageRef image, NSError *error))completion
{
  // if no callback queue is supplied, run on the main thread
  if (callbackQueue == nil) {
    callbackQueue = dispatch_get_main_queue();
  }
  
  // call completion blocks
  void (^handler)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
    // add an artificial delay
    usleep(1.0 * USEC_PER_SEC);
    
    // ASMultiplexImageNode callbacks
    dispatch_async(callbackQueue, ^{
      if (downloadProgressBlock) {
        downloadProgressBlock(1.0f);
      }
      
      if (completion) {
        completion([[UIImage imageWithData:data] CGImage], connectionError);
      }
    });
  };
  
  // let NSURLConnection do the heavy lifting
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  [NSURLConnection sendAsynchronousRequest:request
                                     queue:[[NSOperationQueue alloc] init]
                         completionHandler:handler];
  
  // return nil, don't support cancellation
  return nil;
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  // no-op, don't support cancellation
}

@end

/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>


@interface ViewController () <ASMultiplexImageNodeDataSource, ASMultiplexImageNodeDelegate, ASImageDownloaderProtocol>
{
  ASMultiplexImageNode *_imageNode;

  UILabel *_textLabel;
}

@end


@implementation ViewController

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;


  // multiplex image node!
  // NB:  we're using a custom downloader with an artificial delay for this demo, but ASBasicImageDownloader works too!
  _imageNode = [[ASMultiplexImageNode alloc] initWithCache:nil downloader:self];
  _imageNode.dataSource = self;
  _imageNode.delegate = self;

  // placeholder colour
  _imageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();

  // load low-quality images before high-quality images
  _imageNode.downloadsIntermediateImages = YES;


  // simple status label
  _textLabel = [[UILabel alloc] init];
  _textLabel.textAlignment = NSTextAlignmentCenter;
  _textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:22.0f];

  // tap to reload
  UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reload:)];
  [_textLabel addGestureRecognizer:gr];


  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubnode:_imageNode];
  [self.view addSubview:_textLabel];

  [self start];
}

- (void)viewWillLayoutSubviews
{
  static CGFloat padding = 40.0f;

  // lay out image
  CGFloat imageWidth = self.view.bounds.size.width - padding;
  CGPoint imageOrigin = CGPointMake(roundf((self.view.bounds.size.width - imageWidth) / 2.0f),
                                    roundf((self.view.bounds.size.height - imageWidth) / 2.0f));
  _imageNode.frame = (CGRect){ imageOrigin, CGSizeMake(imageWidth, imageWidth) };

  // label
  CGSize textSize = [_textLabel sizeThatFits:CGSizeMake(self.view.bounds.size.width, FLT_MAX)];
  _textLabel.frame = CGRectMake(0.0f, imageOrigin.y + imageWidth + padding, self.view.bounds.size.width, textSize.height);
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)start
{
  _textLabel.text = @"loading…";
  _textLabel.userInteractionEnabled = NO;

  _imageNode.imageIdentifiers = @[ @"best", @"medium", @"worst" ]; // go!
}

- (void)reload:(id)sender {
  [self start];
  [_imageNode reloadImageIdentifierSources];
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
  _textLabel.text = [NSString stringWithFormat:@"loaded '%@'", imageIdentifier];

  if ([imageIdentifier isEqualToString:@"best"]) {
    _textLabel.text = [_textLabel.text stringByAppendingString:@".  tap to reload"];
    _textLabel.userInteractionEnabled = YES;
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

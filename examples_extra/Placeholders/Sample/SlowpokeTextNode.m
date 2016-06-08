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

#import "SlowpokeTextNode.h"

@implementation SlowpokeTextNode

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  id original = [super drawParametersForAsyncLayer:layer];
  return @{
    @"original" : original,
    @"delay" : @(1.0)
  };
}

+ (void)drawRect:(CGRect)bounds withParameters:(NSDictionary *)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing
{
  usleep( (long)([parameters[@"delay"] floatValue] * USEC_PER_SEC) ); // artificial delay of 1.0
  
  id originalParameter = parameters[@"original"];
  [super drawRect:bounds withParameters:originalParameter isCancelled:isCancelledBlock isRasterizing:isRasterizing];
}

@end

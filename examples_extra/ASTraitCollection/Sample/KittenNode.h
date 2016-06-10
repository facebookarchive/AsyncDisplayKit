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

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface KittenNode : ASCellNode
@property (nonatomic, strong, readonly) ASNetworkImageNode *imageNode;
@property (nonatomic, strong, readonly) ASTextNode *textNode;

@property (nonatomic, copy) dispatch_block_t imageTappedBlock;

// The default action when an image node is tapped. This action will create an
// OverrideVC and override its display traits to always be compact.
+ (void)defaultImageTappedAction:(ASViewController *)sourceViewController;
@end

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

/*
 * A simple node that displays the attribution for the kitties in the app. Note that
 * for a regular horizontal size class it does something stupid and sets the font size to 100.
 * It's VC, OverrideViewController, will have its display traits overridden such that
 * it will always have a compact horizontal size class.
 */
@interface OverrideNode : ASDisplayNode
@end

/*
 * This is a fairly stupid VC that's main purpose is to show how to override ASDisplayTraits.
 * Take a look at `defaultImageTappedAction` in KittenNode to see how this is accomplished.
 */
@interface OverrideViewController : ASViewController<OverrideNode *>
@property (nonatomic, copy) dispatch_block_t closeBlock;
@end

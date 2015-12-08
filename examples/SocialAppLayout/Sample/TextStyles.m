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

#import "TextStyles.h"

@implementation TextStyles

+ (NSDictionary *)nameStyle
{
    return @{
             NSFontAttributeName : [UIFont boldSystemFontOfSize:15.0],
             NSForegroundColorAttributeName: [UIColor blackColor]
    };
}

+ (NSDictionary *)usernameStyle
{
    return @{
             NSFontAttributeName : [UIFont systemFontOfSize:13.0],
             NSForegroundColorAttributeName: [UIColor lightGrayColor]
             };
}

+ (NSDictionary *)timeStyle
{
    return @{
             NSFontAttributeName : [UIFont systemFontOfSize:13.0],
             NSForegroundColorAttributeName: [UIColor grayColor]
             };
}

+ (NSDictionary *)postStyle
{
    return @{
             NSFontAttributeName : [UIFont systemFontOfSize:15.0],
             NSForegroundColorAttributeName: [UIColor blackColor]
             };
}

+ (NSDictionary *)postLinkStyle
{
    return @{
             NSFontAttributeName : [UIFont systemFontOfSize:15.0],
             NSForegroundColorAttributeName: [UIColor colorWithRed:59.0/255.0 green:89.0/255.0 blue:152.0/255.0 alpha:1.0],
             NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
             };
}

+ (NSDictionary *)cellControlStyle {
    
    return @{
             NSFontAttributeName : [UIFont systemFontOfSize:13.0],
             NSForegroundColorAttributeName: [UIColor lightGrayColor]
             };
}

+ (NSDictionary *)cellControlColoredStyle {
    
    return @{
             NSFontAttributeName : [UIFont systemFontOfSize:13.0],
             NSForegroundColorAttributeName: [UIColor colorWithRed:59.0/255.0 green:89.0/255.0 blue:152.0/255.0 alpha:1.0]
             };
}

@end

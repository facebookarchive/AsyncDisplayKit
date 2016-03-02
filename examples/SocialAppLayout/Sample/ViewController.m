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
#import "Post.h"
#import "PostNode.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#include <stdlib.h>

@interface ViewController () <ASTableViewDataSource, ASTableViewDelegate>

@property (nonatomic, strong) ASTableView *tableView;
@property (nonatomic, strong) NSMutableArray *socialAppDataSource;

@end


@implementation ViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.title = @"Timeline";
        [self createSocialAppDataSource];
    }
    return self;
}


- (void)dealloc
{
    _tableView.asyncDataSource = nil;
    _tableView.asyncDelegate = nil;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.tableView = [[ASTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain asyncDataFetching:YES];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // SocialAppNode has its own separator
    self.tableView.asyncDataSource = self;
    self.tableView.asyncDelegate = self;
    [self.view addSubview:self.tableView];
}

- (void)createSocialAppDataSource {
    
    _socialAppDataSource = [[NSMutableArray alloc] init];
    
    Post *newPost = [[Post alloc] init];
    newPost.name = @"Apple Guy";
    newPost.username = @"@appleguy";
    newPost.photo = @"https://avatars1.githubusercontent.com/u/565251?v=3&s=96";
    newPost.post = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";
    newPost.time = @"3s";
    newPost.media = @"";
    newPost.via = 0;
    newPost.likes = arc4random_uniform(74);
    newPost.comments = arc4random_uniform(40);
    [_socialAppDataSource addObject:newPost];
    
    newPost = [[Post alloc] init];
    newPost.name = @"Huy Nguyen";
    newPost.username = @"@nguyenhuy";
    newPost.photo = @"https://avatars2.githubusercontent.com/u/587874?v=3&s=96";
    newPost.post = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";
    newPost.time = @"1m";
    newPost.media = @"";
    newPost.via = 1;
    newPost.likes = arc4random_uniform(74);
    newPost.comments = arc4random_uniform(40);
    [_socialAppDataSource addObject:newPost];
    
    newPost = [[Post alloc] init];
    newPost.name = @"Alex Long Name";
    newPost.username = @"@veryyyylongusername";
    newPost.photo = @"https://avatars1.githubusercontent.com/u/8086633?v=3&s=96";
    newPost.post = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";
    newPost.time = @"3:02";
    newPost.media = @"http://www.ngmag.ru/upload/iblock/f93/f9390efc34151456598077c1ba44a94d.jpg";
    newPost.via = 2;
    newPost.likes = arc4random_uniform(74);
    newPost.comments = arc4random_uniform(40);
    [_socialAppDataSource addObject:newPost];
    
    newPost = [[Post alloc] init];
    newPost.name = @"Vitaly Baev";
    newPost.username = @"@vitalybaev";
    newPost.photo = @"https://avatars0.githubusercontent.com/u/724423?v=3&s=96";
    newPost.post = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. https://github.com/facebook/AsyncDisplayKit Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";
    newPost.time = @"yesterday";
    newPost.media = @"";
    newPost.via = 1;
    newPost.likes = arc4random_uniform(74);
    newPost.comments = arc4random_uniform(40);
    [_socialAppDataSource addObject:newPost];
}

#pragma mark - ASTableView

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    Post *post = self.socialAppDataSource[indexPath.row];
    return ^{
        return [[PostNode alloc] initWithPost:post];
    };
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.socialAppDataSource.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    PostNode *postNode = (PostNode *)[_tableView nodeForRowAtIndexPath:indexPath];
    Post *post = self.socialAppDataSource[indexPath.row];
  
    BOOL shouldRasterize = postNode.shouldRasterizeDescendants;
    shouldRasterize = !shouldRasterize;
    postNode.shouldRasterizeDescendants = shouldRasterize;
    
    NSLog(@"%@ rasterization for %@'s post: %@", shouldRasterize ? @"Enabling" : @"Disabling", post.name, postNode);
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

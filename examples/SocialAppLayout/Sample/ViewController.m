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
{
    ASTableView *_tableView;
    
    NSMutableArray *_socialAppDataSource;

}

@end

@implementation ViewController

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    
    _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain asyncDataFetching:YES];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // SocialAppNode has its own separator
    _tableView.asyncDataSource = self;
    _tableView.asyncDelegate = self;
    
    [self createSocialAppDataSource];
    
    self.title = @"Timeline";
    
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self.view addSubview:_tableView];
}

- (void)viewWillLayoutSubviews
{
    _tableView.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
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

#pragma mark -
#pragma mark ASTableView.

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Post *post = _socialAppDataSource[indexPath.row];
    PostNode *node = [[PostNode alloc] initWithPost:post];
    return node;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _socialAppDataSource.count;
}

@end

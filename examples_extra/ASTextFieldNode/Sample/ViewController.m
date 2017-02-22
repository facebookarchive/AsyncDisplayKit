//
//  ViewController.m
//  Sample
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

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ViewController () <ASEditableTextNodeDelegate>
{
  ASTextFieldNode *_textFieldNode;
  ASTextFieldNode *_passwordFieldNode;
}
@end


@implementation ViewController

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _textFieldNode = [[ASTextFieldNode alloc] init];
  _textFieldNode.textContainerInset = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
  _textFieldNode.returnKeyType = UIReturnKeyDone;
  _textFieldNode.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.1f];
  
  _passwordFieldNode = [[ASTextFieldNode alloc] init];
  _passwordFieldNode.textContainerInset = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
  _passwordFieldNode.returnKeyType = UIReturnKeyGo;
  _passwordFieldNode.secureTextEntry = true;
  _passwordFieldNode.backgroundColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.5f];
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubnode:_textFieldNode];
  [self.view addSubnode:_passwordFieldNode];
}

- (void)viewWillLayoutSubviews
{
  // place the text node in the top half of the screen, with a bit of padding
  _textFieldNode.frame = CGRectMake(0, 20, self.view.bounds.size.width, 51.0);
  _passwordFieldNode.frame = CGRectMake(0, 71.0, self.view.bounds.size.width, 51.0);
}

@end

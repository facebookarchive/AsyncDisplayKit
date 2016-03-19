//
//  ViewController.m
//  Sample
//
//  Created by Erekle on 3/19/16.
//  Copyright © 2016 facebook. All rights reserved.
//

#import "ViewController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASVideoNode.h>
@interface ViewController ()<ASVideoNodeDelegate>{
    ASVideoNode *_videoNode;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    CGRect videoNodeRect = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height/3);
    
    _videoNode = [[ASVideoNode alloc] init];
    _videoNode.delegate = self;
    _videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"https://files.parsetfss.com/8a8a3b0c-619e-4e4d-b1d5-1b5ba9bf2b42/tfss-753fe655-86bb-46da-89b7-aa59c60e49c0-niccage.mp4"]];
    _videoNode.frame = videoNodeRect;
    [self.view addSubnode:_videoNode];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ASVideoNodeDelegate
- (void)videoPlaybackDidFinish:(ASVideoNode *)videoNode{
    NSLog(@"videoPlaybackDidFinish");
}

- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toSate{
    NSLog(@"Current State : %d",state);
    NSLog(@"Next State : %d",toSate);
}

- (BOOL)videoNode:(ASVideoNode *)videoNode shouldChangePlayerStateTo:(ASVideoNodePlayerState)state{
    if(state == ASVideoNodePlayerStatePaused){
        return NO;
    }
    return YES;
}

@end

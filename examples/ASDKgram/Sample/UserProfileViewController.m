//
//  UserProfileViewController.m
//  Flickrgram
//
//  Created by Hannah Troisi on 2/24/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "UserProfileViewController.h"
#import "Utilities.h"

#define HEADER_HEIGHT           300
#define USER_AVATAR_HEIGHT      70
#define HEADER_HORIZONTAL_INSET 15

#define DEBUG_LAYOUT            0

@implementation UserProfileViewController
{
  UserModel    *_user;
  
  UIImageView  *_avatarImageView;
  UIButton     *_followingStatusBtn;
  UILabel      *_fullNameLabel;
  UILabel      *_aboutLabel;
  UILabel      *_domainLabel;
  UILabel      *_followersCountLabel;
  UILabel      *_followingCountLabel;
  UILabel      *_photoCountLabel;
  
  BOOL         _animating;
}

//- (instancetype)initWithMe
//{
//  UserModel *me = [[UserModel alloc] initWithMe];
//  
//  [self initWithUser:me];
//}

- (instancetype)initWithUser:(UserModel *)user
{
  self = [super initWithNibName:nil bundle:nil];
  
  if (self) {
    
    self.view.backgroundColor = [UIColor whiteColor];

    _followingStatusBtn            = [UIButton buttonWithType:UIButtonTypeCustom];
    _followingStatusBtn.adjustsImageWhenHighlighted = NO;
    [_followingStatusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_followingStatusBtn setTitleColor:[UIColor lightBlueColor] forState:UIControlStateSelected];
    [_followingStatusBtn setTitle:@"Follow" forState:UIControlStateNormal];
    [_followingStatusBtn setTitle:@"Following" forState:UIControlStateSelected];
    [_followingStatusBtn addTarget:self action:@selector(toggleFollowing) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_followingStatusBtn];
    
    _fullNameLabel                 = [[UILabel alloc] init];
    _fullNameLabel.font            = [_fullNameLabel.font fontWithSize:14];
    [self.view addSubview:_fullNameLabel];

    _aboutLabel                    = [[UILabel alloc] init];
    _aboutLabel.font               = [_aboutLabel.font fontWithSize:14];
    _aboutLabel.numberOfLines      = 3;
    [self.view addSubview:_aboutLabel];
    
    _domainLabel                   = [[UILabel alloc] init];
    _domainLabel.font              = [_domainLabel.font fontWithSize:14];
    _domainLabel.textColor         = [UIColor darkBlueColor];
    [self.view addSubview:_domainLabel];

    _followersCountLabel               = [[UILabel alloc] init];
    _followersCountLabel.font          = [_followersCountLabel.font fontWithSize:14];
    _followersCountLabel.textColor     = [UIColor lightGrayColor];
    _followersCountLabel.textAlignment = NSTextAlignmentCenter;
    _followersCountLabel.numberOfLines = 2;
    [self.view addSubview:_followersCountLabel];

    _followingCountLabel               = [[UILabel alloc] init];
    _followingCountLabel.font          = [_followingCountLabel.font fontWithSize:14];
    _followingCountLabel.textColor     = [UIColor lightGrayColor];
    _followingCountLabel.textAlignment = NSTextAlignmentCenter;
    _followingCountLabel.numberOfLines = 2;
    [self.view addSubview:_followingCountLabel];
    
    _photoCountLabel               = [[UILabel alloc] init];
    _photoCountLabel.font          = [_photoCountLabel.font fontWithSize:14];
    _photoCountLabel.textColor     = [UIColor lightGrayColor];
    _photoCountLabel.textAlignment = NSTextAlignmentCenter;
    _photoCountLabel.numberOfLines = 2;
    [self.view addSubview:_photoCountLabel];
    
    // add to view last so that animation is on top
    _avatarImageView               = [[UIImageView alloc] init];
    [self.view addSubview:_avatarImageView];
    
    // This is what we have available as soon as we're created, without fetching new metadata from the network.
    _fullNameLabel.text            = _user.fullName;
    _user                          = user;
    self.navigationItem.title      = [user.username uppercaseString];
    
    // get full set of user data
    [self loadAdditionalProfileFields];
    
    // get avatar image
    [self loadAvatarImage];
    
    
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(viewWasLongPressed:)];
//    [self.view addGestureRecognizer:lpgr];
    lpgr.minimumPressDuration = 0.01;
    
    if (DEBUG_LAYOUT) {
      _avatarImageView.backgroundColor      = [UIColor greenColor];
      _fullNameLabel.backgroundColor        = [UIColor greenColor];
      _aboutLabel.backgroundColor           = [UIColor greenColor];
      _domainLabel.backgroundColor          = [UIColor greenColor];
      _followersCountLabel.backgroundColor  = [UIColor greenColor];
      _followingCountLabel.backgroundColor  = [UIColor greenColor];
      _photoCountLabel.backgroundColor      = [UIColor greenColor];
    }
  }
  return self;
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGSize boundsSize = self.view.bounds.size;
  
  if (_animating) {
    return;
  }
  
  // user avatar
  CGFloat x = HEADER_HORIZONTAL_INSET;
  CGFloat originalY = CGRectGetMaxY(self.navigationController.navigationBar.frame) + HEADER_HORIZONTAL_INSET;
  CGFloat y = originalY;
  _avatarImageView.frame = CGRectMake(x,
                                      y,
                                      USER_AVATAR_HEIGHT,
                                      USER_AVATAR_HEIGHT);
  y += _avatarImageView.frame.size.height;
  
  if (!_avatarImageView.image) {
    // We generate the rounded image at layout time (unusually late) so that we can know exactly how large
    // it needs to be.  This is the only way to ensure the rounded curve is perfectly smoothed / antialiased.
//    _avatarImageView.image = [avatar makeCircularImageWithSize:CGSizeMake(USER_AVATAR_HEIGHT, USER_AVATAR_HEIGHT)];
  }
  
  if (_fullNameLabel.text) {
    [_fullNameLabel sizeToFit];
    y += HEADER_HORIZONTAL_INSET / 2.0;
    _fullNameLabel.frame = CGRectMake(x,
                                      y,
                                      boundsSize.width - 2 * HEADER_HORIZONTAL_INSET,
                                      _fullNameLabel.frame.size.height);
    
    y += _fullNameLabel.frame.size.height;
  }
  
  if (_aboutLabel.text) {
    [_aboutLabel sizeToFit];
    y += HEADER_HORIZONTAL_INSET / 2.0;
    _aboutLabel.frame = CGRectMake(x,
                                   y,
                                   boundsSize.width - 2 * HEADER_HORIZONTAL_INSET,
                                   _aboutLabel.frame.size.height);
    
    y += _aboutLabel.frame.size.height;
  }
  
  if (_domainLabel.text) {
    [_domainLabel sizeToFit];
    y += HEADER_HORIZONTAL_INSET / 2.0;
    _domainLabel.frame = CGRectMake(x,
                                    y,
                                    boundsSize.width - 2 * HEADER_HORIZONTAL_INSET,
                                    _domainLabel.frame.size.height);
  }

  CGFloat availableWidth = boundsSize.width - 3 * HEADER_HORIZONTAL_INSET - USER_AVATAR_HEIGHT;
  CGFloat actualWidth = floorf((availableWidth - 2 * HEADER_HORIZONTAL_INSET / 2.0) / 3.0);
  
  y = originalY;
  x += USER_AVATAR_HEIGHT + HEADER_HORIZONTAL_INSET;
  
  [_photoCountLabel sizeToFit];
  _photoCountLabel.frame = CGRectMake(x,
                                      y,
                                      actualWidth,
                                      _photoCountLabel.frame.size.height);
  x += actualWidth;
  
  [_followersCountLabel sizeToFit];
  x += HEADER_HORIZONTAL_INSET / 2.0;
  _followersCountLabel.frame = CGRectMake(x,
                                          y,
                                          actualWidth,
                                          _followersCountLabel.frame.size.height);
  x += actualWidth;
  
  [_followingCountLabel sizeToFit];
  x += HEADER_HORIZONTAL_INSET / 2.0;
  _followingCountLabel.frame = CGRectMake(x,
                                          y,
                                          actualWidth,
                                          _followingCountLabel.frame.size.height);
  
  x = USER_AVATAR_HEIGHT + 2 * HEADER_HORIZONTAL_INSET;
  y = originalY + USER_AVATAR_HEIGHT / 2.0;
  _followingStatusBtn.frame = CGRectMake(x,
                                         y,
                                         availableWidth,
                                         USER_AVATAR_HEIGHT / 2.0);
  
  [self setFollowingButtonBackgroundsForRect:_followingStatusBtn.frame.size];
}


#pragma mark - Touch Events

- (void)viewWasLongPressed:(UIGestureRecognizer *)sender
{

  if (sender.state == UIGestureRecognizerStateBegan) {
    
    // determine which area of cell was tapped
    CGPoint tapPoint = [sender locationInView:_avatarImageView];
    
    if (tapPoint.y > 0) {
      
      NSLog(@"LONG PRESS STARTED");
      
      _animating = YES;
      
      // FIXME: use pinremote image to download higher res photo
          
      [UIView animateWithDuration:0.2
                            delay:0
           usingSpringWithDamping:0.5
            initialSpringVelocity:1.0f
                          options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                       animations:^{
        
        // FIXME: grey the background
                         
        _avatarImageView.frame = CGRectMake(100, 100, 100, 100);
        
      } completion:^(BOOL finished) {
        _animating = NO;
      }];
    }
  }
  
  if (sender.state == UIGestureRecognizerStateEnded) {
    
    // determine which area of cell was tapped
    CGPoint tapPoint = [sender locationInView:_avatarImageView];
    
    if (tapPoint.y > 0) {   // FIXME: all long presses work here
      
      NSLog(@"LONG PRESS ENDED");
      
       _animating = YES;
      
      [UIView animateWithDuration:0.2
                            delay:0
           usingSpringWithDamping:0.5
            initialSpringVelocity:1.0f
                          options: UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                       animations:^{
        
        CGFloat x = HEADER_HORIZONTAL_INSET;
        CGFloat originalY = CGRectGetMaxY(self.navigationController.navigationBar.frame) + HEADER_HORIZONTAL_INSET;
        CGFloat y = originalY;
        _avatarImageView.frame = CGRectMake(x,
                                            y,
                                            USER_AVATAR_HEIGHT,
                                            USER_AVATAR_HEIGHT);
        
      } completion:^(BOOL finished) {
        _animating = NO;
        
      }];
      
    }
  }
}

- (void)toggleFollowing
{
  // toggle button state
  if (_followingStatusBtn.selected) {
    
    // stop following
    NSString *urlString = [NSString stringWithFormat:@"https://api.500px.com/v1/users/%lu/friends?consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC", (long)_user.userID];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"DELETE"];
    
    // FIXME: update user model
    // FIXME: check for success
    
  } else {
    
    // start following
    NSString *urlString = [NSString stringWithFormat:@"https://api.500px.com/v1/users/%lu/friends?consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC", (long)_user.userID];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
  }

  _followingStatusBtn.selected = !_followingStatusBtn.selected;
}

- (void)getFollowers
{
  NSString *urlString = [NSString stringWithFormat:@"https://api.500px.com/v1/users/%lu/friends?consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC", (long)_user.userID];
  NSURL *url = [NSURL URLWithString:urlString];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setHTTPMethod:@"GET"];
}

#pragma mark - Helper Methods

- (void)loadAdditionalProfileFields
{
  // fetch full user profile info
  [_user downloadCompleteUserDataWithCompletionBlock:^(UserModel *userModel) {

    // check that info returning from async download is still applicable to this view
    if (userModel == _user) {
      
      _followingStatusBtn.selected = userModel.following;
      _followersCountLabel.text    = [NSString stringWithFormat:@"%lu\nfollowers", (long)userModel.followersCount];
      _followingCountLabel.text    = [NSString stringWithFormat:@"%lu\nfollowing", (long)userModel.friendsCount];
      _photoCountLabel.text        = [NSString stringWithFormat:@"%lu\nphotos", (long)userModel.photoCount];
      _aboutLabel.text             = userModel.about;
      _domainLabel.text            = userModel.domain;
      
      [self.view setNeedsLayout];
    }
  }];
}

- (void)loadAvatarImage
{
  [_user fetchAvatarImageWithCompletionBlock:^(UserModel *userModel, UIImage *avatar) {
    
    // check that info returning from async download is still applicable to this view
    if (userModel == _user) {
      [self.view setNeedsLayout];
    }
  }];
}

#define FOLLOW_BUTTON_CORNER_RADIUS 8
- (void)setFollowingButtonBackgroundsForRect:(CGSize)size
{
  CGSize unstretchedSize  = CGSizeMake(2 * FOLLOW_BUTTON_CORNER_RADIUS + 1, 2 * FOLLOW_BUTTON_CORNER_RADIUS + 1);
  CGRect rect             = (CGRect) {CGPointZero, unstretchedSize};
  UIBezierPath *path      = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:FOLLOW_BUTTON_CORNER_RADIUS];
  
  UIColor *lightBlue      = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];

  // create a graphics context for the following status button
  UIGraphicsBeginImageContextWithOptions(unstretchedSize, NO, 0);
  
  [path addClip];
  [lightBlue setFill];
  [path fill];
  
  UIImage *notFollowingBtnImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  UIImage *notFollowingBtnImageStretchable = [notFollowingBtnImage stretchableImageWithLeftCapWidth:FOLLOW_BUTTON_CORNER_RADIUS topCapHeight:FOLLOW_BUTTON_CORNER_RADIUS];
  [_followingStatusBtn setBackgroundImage:notFollowingBtnImageStretchable forState:UIControlStateNormal];

  // create a graphics context for the not yet following status button
  UIGraphicsBeginImageContextWithOptions(unstretchedSize, NO, 0);
  
  [path addClip];
  
  [[UIColor whiteColor] setFill];
  [path fill];
  
  path.lineWidth = 3;
  [lightBlue setStroke];
  [path stroke];
  
  UIImage *followingBtnImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  UIImage *followingBtnImageStretchable = [followingBtnImage stretchableImageWithLeftCapWidth:FOLLOW_BUTTON_CORNER_RADIUS topCapHeight:FOLLOW_BUTTON_CORNER_RADIUS];
  [_followingStatusBtn setBackgroundImage:followingBtnImageStretchable forState:UIControlStateSelected];
}

@end

---
title: Implicit Node Hierarchy Mgmt
layout: docs
permalink: /docs/implicit-hierarchy-mgmt.html
next: debug-hit-test.html
---

This feature - created by ASDK rockstar <a href="https://github.com/facebook/AsyncDisplayKit/pulls?utf8=%E2%9C%93&q=is%3Apr+author%3Alevi+">@levi</a> - was built to support the AsyncDisplayKit Layout Transition API. However, apps using AsyncDisplayKit that don't require animations can still benefit from the reduction in code size that this feature enables.

**This feature will soon be enabled by default.**

<div class = "note">
Implicit Node Hierarchy Management (INHM) is implemented using ASLayoutSpecs. If you are unfamiliar with that concept, please read that documentation (INSERT LINK) first. 
To recap, an ASLayoutSpec completely describes the UI of a view in your app by specifying the **hierarchy state of a node and its subnodes**. An ASLayoutSpec is returned by a node from its 
`- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize`
method. 
</div>

When enabled, INHM, means that your nodes no longer require `addSubnode:` or `removeFromSupernode` method calls. The presence or absence of the INHM node _and_ its subnodes are determined in the layoutSpecThatFits: method. 

**Note that the subnodes of any node with this property set will inherit INHM, so it is only neccessary to put it on the highest level node. Most likely that will be an ASTableNode, ASCollectionNode or ASPagerNode.**

####Example####
Consider the following `ASCellNode` subclass `PhotoCellNode` from the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> which produces a simple social media photo feed UI.

```objective-c
- (instancetype)initWithPhotoObject:(PhotoModel *)photo;
{
  self = [super init];
  
  if (self) {
  
    self.usesImplicitHierarchyManagement = YES;
    
    _photoModel              = photo;
    
    _userAvatarImageView     = [[ASNetworkImageNode alloc] init];
    _userAvatarImageView.URL = photo.ownerUserProfile.userPicURL;

    _photoImageView          = [[ASNetworkImageNode alloc] init];
    _photoImageView.URL      = photo.URL;

    _userNameLabel                  = [[ASTextNode alloc] init];
    _userNameLabel.attributedString = [photo.ownerUserProfile usernameAttributedStringWithFontSize:FONT_SIZE];
    
    _photoLocationLabel      = [[ASTextNode alloc] init];
    [photo.location reverseGeocodedLocationWithCompletionBlock:^(LocationModel *locationModel) {
      if (locationModel == _photoModel.location) {
        _photoLocationLabel.attributedString = [photo locationAttributedStringWithFontSize:FONT_SIZE];
        [self setNeedsLayout];
      }
    }];

    _photoCommentsView = [[CommentsNode alloc] init];
  }
  
  return self;
}

```

By setting usesImplicitHierarchyManagement to YES on the ASCellNode, we _no longer_ need to call `addSubnode:` for each of the ASCellNode's subnodes.

Several of the elements in this cell - `_userAvatarImageView`, `_photoImageView`, `_photoLocationLabel` and `_photoCommentsView` - depend on seperate data fetches from the network that could return at any time. 

Implicit Hierarchy Management knows whether or not to include these elements in the UI based on information provided in the cell's ASLayoutSpec. 

**It is your job to construct a `layoutSpecThatFits:` that handles how the UI should look with and without these elements.**

Consider the layoutSpecThatFits: method for the ASCellNode subclass

```objective-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // username / photo location header vertical stack
  _photoLocationLabel.flexShrink    = YES;
  _userNameLabel.flexShrink         = YES;
  
  ASStackLayoutSpec *headerSubStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  headerSubStack.flexShrink         = YES;
  if (_photoLocationLabel.attributedString) {
    [headerSubStack setChildren:@[_userNameLabel, _photoLocationLabel]];
  } else {
    [headerSubStack setChildren:@[_userNameLabel]];
  }
  
  // header stack
  _userAvatarImageView.preferredFrameSize        = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);     // constrain avatar image frame size

  ASLayoutSpec *spacer           = [[ASLayoutSpec alloc] init]; 
  spacer.flexGrow                = YES;
  
  UIEdgeInsets avatarInsets      = UIEdgeInsetsMake(HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *avatarInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:avatarInsets child:_userAvatarImageView];

  ASStackLayoutSpec *headerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStack.alignItems         = ASStackLayoutAlignItemsCenter;                     // center items vertically in horizontal stack
  headerStack.justifyContent     = ASStackLayoutJustifyContentStart;                  // justify content to the left side of the header stack
  [headerStack setChildren:@[avatarInset, headerSubStack, spacer]];
  
  // header inset stack
  UIEdgeInsets insets                = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:headerStack];
  
  // footer inset stack
  UIEdgeInsets footerInsets          = UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *footerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:footerInsets child:_photoCommentsView];
  
  // vertical stack
  CGFloat cellWidth                  = constrainedSize.max.width;
  _photoImageView.preferredFrameSize = CGSizeMake(cellWidth, cellWidth);              // constrain photo frame size
  
  ASStackLayoutSpec *verticalStack   = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.alignItems           = ASStackLayoutAlignItemsStretch;                // stretch headerStack to fill horizontal space
  [verticalStack setChildren:@[headerWithInset, _photoImageView, footerWithInset]];

  return verticalStack;
}
```

Here you can see that I set the children of my `headerSubStack` to depending on wehther or not the `_photoLocationLabel` attributed string has returned from the reverseGeocode process yet. 

The `_userAvatarImageView`, `_photoImageView`, and `_photoCommentsView` are added into the ASLayoutSpec, but will not show up until their data fetches return.

####Updating an ASLayoutSpec####

**If something happens that you know will change your `ASLayoutSpec`,  it is your job to call `-setNeedsLayout`** (equivalent to `transitionLayout:duration:0` that will be mentioned in the Transition Layout API). As can be seen in the completion block of the photo.location reverseGeocodedLocationWithCompletionBlock: call above. 

An appropriately constructed ASLayoutSpec will know which subnodes need to be added, removed or animated. 

If you try out the ASDKgram sample app after looking at the code above, you can see how simple it is to code a cell node thats layout is responsive to numerous, individual data fetches and returns. While the ASLayoutSpec is coded in a way that leaves holes for the avatar and photo to populate, you can see how the cell's height will automatically adjust to accomodate the comments node at the bottom of the photo. 

This is just a simple example, but this feature has many more powerful uses. 

####To Use####

- import `"ASDisplayNode+Beta.h"`
- set the `.usesImplicitHierarchyManagement = YES` on the node that you would like managed. 
 
**Note that the subnodes of any node with this property set will inherit the property, so it is only neccessary to put it on the highest level node. Most likely that will be an ASTableNode, ASCollectionNode or ASPagerNode.**

Please check it out and let us know what you think at <a href="https://github.com/facebook/AsyncDisplayKit/pull/1156">PR #1156</a>!

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

#import "PostNode.h"
#import "TextStyles.h"
#import "LikesNode.h"
#import "CommentsNode.h"

@interface PostNode() <ASNetworkImageNodeDelegate>
@end

@implementation PostNode

- (instancetype)initWithPost:(Post *)post {
    
    self = [super init];
    
    if(self) {
        
        _post = post;
        
        // name node
        _nameNode = [[ASTextNode alloc] init];
        _nameNode.attributedString = [[NSAttributedString alloc] initWithString:_post.name
                                                                     attributes:[TextStyles nameStyle]];
        _nameNode.maximumNumberOfLines = 1;
        [self addSubnode:_nameNode];
        
        // username node
        _usernameNode = [[ASTextNode alloc] init];
        _usernameNode.attributedString = [[NSAttributedString alloc] initWithString:_post.username
                                                                     attributes:[TextStyles usernameStyle]];
        _usernameNode.flexShrink = YES; //if name and username don't fit to cell width, allow username shrink
        _usernameNode.truncationMode = NSLineBreakByTruncatingTail;
        _usernameNode.maximumNumberOfLines = 1;
        
        [self addSubnode:_usernameNode];
        
        // time node
        _timeNode = [[ASTextNode alloc] init];
        _timeNode.attributedString = [[NSAttributedString alloc] initWithString:_post.time
                                                                     attributes:[TextStyles timeStyle]];
        [self addSubnode:_timeNode];
        
        // post node
        _postNode = [[ASTextNode alloc] init];
    
        // processing URLs in post
        NSString *kLinkAttributeName = @"TextLinkAttributeName";
        
        if(![_post.post isEqualToString:@""]) {
            
            NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:_post.post attributes:[TextStyles postStyle]];
            
            NSDataDetector *urlDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
            
            [urlDetector enumerateMatchesInString:attrString.string options:kNilOptions range:NSMakeRange(0, attrString.string.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
                
                if (result.resultType == NSTextCheckingTypeLink) {
                    
                    NSMutableDictionary *linkAttributes = [[NSMutableDictionary alloc] initWithDictionary:[TextStyles postLinkStyle]];
                    linkAttributes[kLinkAttributeName] = [NSURL URLWithString:result.URL.absoluteString];
                    
                    [attrString addAttributes:linkAttributes range:result.range];
                  
                }
                
            }];
            
            // configure node to support tappable links
            _postNode.delegate = self;
            _postNode.userInteractionEnabled = YES;
            _postNode.linkAttributeNames = @[ kLinkAttributeName ];
            _postNode.attributedString = attrString;
            
        }
        
        [self addSubnode:_postNode];
        
        // media
        
        if(![_post.media isEqualToString:@""]) {
            
            _mediaNode = [[ASNetworkImageNode alloc] init];
            _mediaNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
            _mediaNode.cornerRadius = 4.0;
            _mediaNode.URL = [NSURL URLWithString:_post.media];
            _mediaNode.delegate = self;
            _mediaNode.imageModificationBlock = ^UIImage *(UIImage *image) {
                
                UIImage *modifiedImage;
                CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
                
                UIGraphicsBeginImageContextWithOptions(image.size, false, [[UIScreen mainScreen] scale]);
                
                [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:8.0] addClip];
                [image drawInRect:rect];
                modifiedImage = UIGraphicsGetImageFromCurrentImageContext();
                
                UIGraphicsEndImageContext();
                
                return modifiedImage;
                
            };
            [self addSubnode:_mediaNode];
        }
        
        // user pic
        _avatarNode = [[ASNetworkImageNode alloc] init];
        _avatarNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
        _avatarNode.preferredFrameSize = CGSizeMake(44, 44);
        _avatarNode.cornerRadius = 22.0;
        _avatarNode.URL = [NSURL URLWithString:_post.photo];
        _avatarNode.imageModificationBlock = ^UIImage *(UIImage *image) {
            
            UIImage *modifiedImage;
            CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
            
            UIGraphicsBeginImageContextWithOptions(image.size, false, [[UIScreen mainScreen] scale]);
            
            [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:44.0] addClip];
            [image drawInRect:rect];
            modifiedImage = UIGraphicsGetImageFromCurrentImageContext();
            
            UIGraphicsEndImageContext();
            
            return modifiedImage;
            
        };
        [self addSubnode:_avatarNode];
        
        // hairline cell separator
        _divider = [[ASDisplayNode alloc] init];
        _divider.backgroundColor = [UIColor lightGrayColor];
        [self addSubnode:_divider];
        
        if(_post.via != 0) {
            
            _viaNode = [[ASImageNode alloc] init];
            _viaNode.image = (_post.via == 1) ? [UIImage imageNamed:@"icon_ios.png"] : [UIImage imageNamed:@"icon_android.png"];
            [self addSubnode:_viaNode];
        }
        
        // bottom controls
        _likesNode = [[LikesNode alloc] initWithLikesCount:_post.likes];
        [self addSubnode:_likesNode];
        
        _commentsNode = [[CommentsNode alloc] initWithCommentsCount:_post.comments];
        [self addSubnode:_commentsNode];
        
        _optionsNode = [[ASImageNode alloc] init];
        _optionsNode.image = [UIImage imageNamed:@"icon_more"];
        [self addSubnode:_optionsNode];
        
    }
    
    return self;
}

- (void)didLoad
{
    // enable highlighting now that self.layer has loaded -- see ASHighlightOverlayLayer.h
    self.layer.as_allowsHighlightDrawing = YES;
    
    [super didLoad];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize {
    
    //Flexible spacer between username and time
    ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
    spacer.flexGrow = YES;
    
    //Horizontal stack for name, username, via icon and time
    ASStackLayoutSpec *nameStack;
    
    //Cases with or without via icon
    if(_post.via != 0) {
        
        nameStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:5.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[_nameNode, _usernameNode, spacer, _viaNode, _timeNode]];
        
    }else {
        nameStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:5.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[_nameNode, _usernameNode, spacer, _timeNode]];
    }
    
    
    nameStack.alignSelf = ASStackLayoutAlignSelfStretch;
    
    // bottom controls horizontal stack
    ASStackLayoutSpec *controlsStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:10 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[_likesNode, _commentsNode, _optionsNode]];
    
    //add more gaps for control line
    controlsStack.spacingAfter = 3.0;
    controlsStack.spacingBefore = 3.0;
    
    NSMutableArray *mainStackContent = [[NSMutableArray alloc] init];
    
    [mainStackContent addObject:nameStack];
    [mainStackContent addObject:_postNode];
    
    if(![_post.media isEqualToString:@""]) {
        
        CGFloat imageRatio;
        
        if(_mediaNode.image != nil) {
            
            imageRatio = _mediaNode.image.size.height / _mediaNode.image.size.width;
            
        }else {
            
            imageRatio = 0.5;
        }
        
        ASRatioLayoutSpec *imagePlace = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:imageRatio child:_mediaNode];
        imagePlace.spacingAfter = 3.0;
        imagePlace.spacingBefore = 3.0;
        
        [mainStackContent addObject:imagePlace];
        
    }
    
    [mainStackContent addObject:controlsStack];
    
    //Vertical spec of cell main content
    ASStackLayoutSpec *contentSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical spacing:8.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStart children:mainStackContent];
    
    
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 64, 10, 10) child:contentSpec];
    
}

- (void)layout
{
    [super layout];
    
    // Manually layout the divider.
    CGFloat pixelHeight = 1.0f / [[UIScreen mainScreen] scale];
    _divider.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, pixelHeight);
    _avatarNode.frame = CGRectMake(10, 10, 44, 44);
}

#pragma mark -
#pragma mark ASTextNodeDelegate methods.

- (BOOL)textNode:(ASTextNode *)richTextNode shouldHighlightLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point
{
    // opt into link highlighting -- tap and hold the link to try it!  must enable highlighting on a layer, see -didLoad
    return YES;
}

- (void)textNode:(ASTextNode *)richTextNode tappedLinkAttribute:(NSString *)attribute value:(NSURL *)URL atPoint:(CGPoint)point textRange:(NSRange)textRange
{
    // the node tapped a link, open it
    [[UIApplication sharedApplication] openURL:URL];
}

#pragma mark -
#pragma mark ASNetworkImageNodeDelegate methods.

- (void)imageNode:(ASNetworkImageNode *)imageNode didLoadImage:(UIImage *)image
{
    [self setNeedsLayout];
}

@end

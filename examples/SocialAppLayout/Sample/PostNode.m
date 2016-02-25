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
#import "Post.h"
#import "TextStyles.h"
#import "LikesNode.h"
#import "CommentsNode.h"

@interface PostNode() <ASNetworkImageNodeDelegate, ASTextNodeDelegate>

@property (strong, nonatomic) Post *post;
@property (strong, nonatomic) ASDisplayNode *divider;
@property (strong, nonatomic) ASTextNode *nameNode;
@property (strong, nonatomic) ASTextNode *usernameNode;
@property (strong, nonatomic) ASTextNode *timeNode;
@property (strong, nonatomic) ASTextNode *postNode;
@property (strong, nonatomic) ASImageNode *viaNode;
@property (strong, nonatomic) ASNetworkImageNode *avatarNode;
@property (strong, nonatomic) ASNetworkImageNode *mediaNode;
@property (strong, nonatomic) LikesNode *likesNode;
@property (strong, nonatomic) CommentsNode *commentsNode;
@property (strong, nonatomic) ASImageNode *optionsNode;

@end

@implementation PostNode

- (instancetype)initWithPost:(Post *)post {
    
    self = [super init];
    if (self) {
        _post = post;
        
        // Name node
        _nameNode = [[ASTextNode alloc] init];
        _nameNode.attributedString = [[NSAttributedString alloc] initWithString:_post.name attributes:[TextStyles nameStyle]];
        _nameNode.maximumNumberOfLines = 1;
        [self addSubnode:_nameNode];
        
        // Username node
        _usernameNode = [[ASTextNode alloc] init];
        _usernameNode.attributedString = [[NSAttributedString alloc] initWithString:_post.username attributes:[TextStyles usernameStyle]];
        _usernameNode.flexShrink = YES; //if name and username don't fit to cell width, allow username shrink
        _usernameNode.truncationMode = NSLineBreakByTruncatingTail;
        _usernameNode.maximumNumberOfLines = 1;
        [self addSubnode:_usernameNode];
        
        // Time node
        _timeNode = [[ASTextNode alloc] init];
        _timeNode.attributedString = [[NSAttributedString alloc] initWithString:_post.time attributes:[TextStyles timeStyle]];
        [self addSubnode:_timeNode];
        
        // Post node
        _postNode = [[ASTextNode alloc] init];

        // Processing URLs in post
        NSString *kLinkAttributeName = @"TextLinkAttributeName";
        
        if (![_post.post isEqualToString:@""]) {
            
            NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:_post.post attributes:[TextStyles postStyle]];
            
            NSDataDetector *urlDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
            
            [urlDetector enumerateMatchesInString:attrString.string options:kNilOptions range:NSMakeRange(0, attrString.string.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
                
                if (result.resultType == NSTextCheckingTypeLink) {
                    
                    NSMutableDictionary *linkAttributes = [[NSMutableDictionary alloc] initWithDictionary:[TextStyles postLinkStyle]];
                    linkAttributes[kLinkAttributeName] = [NSURL URLWithString:result.URL.absoluteString];
                    
                    [attrString addAttributes:linkAttributes range:result.range];
                  
                }
                
            }];
            
            // Configure node to support tappable links
            _postNode.delegate = self;
            _postNode.userInteractionEnabled = YES;
            _postNode.linkAttributeNames = @[ kLinkAttributeName ];
            _postNode.attributedString = attrString;
            
        }
        
        [self addSubnode:_postNode];
        
        
        // Media
        if (![_post.media isEqualToString:@""]) {
            
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
        
        // User pic
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
        
        // Hairline cell separator
        _divider = [[ASDisplayNode alloc] init];
        _divider.backgroundColor = [UIColor lightGrayColor];
        [self addSubnode:_divider];
        
        // Via
        if (_post.via != 0) {
            _viaNode = [[ASImageNode alloc] init];
            _viaNode.image = (_post.via == 1) ? [UIImage imageNamed:@"icon_ios.png"] : [UIImage imageNamed:@"icon_android.png"];
            [self addSubnode:_viaNode];
        }
        
        // Bottom controls
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
    
    // Flexible spacer between username and time
    ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
    spacer.flexGrow = YES;
    
    // Horizontal stack for name, username, via icon and time
    NSMutableArray *layoutSpecChildren = [@[_nameNode, _usernameNode, spacer] mutableCopy];
    if (_post.via != 0) {
        [layoutSpecChildren addObject:_viaNode];
    }
    [layoutSpecChildren addObject:_timeNode];
    
    ASStackLayoutSpec *nameStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:5.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:layoutSpecChildren];
    nameStack.alignSelf = ASStackLayoutAlignSelfStretch;
    
    // bottom controls horizontal stack
    ASStackLayoutSpec *controlsStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:10 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsCenter children:@[_likesNode, _commentsNode, _optionsNode]];
    
    // Add more gaps for control line
    controlsStack.spacingAfter = 3.0;
    controlsStack.spacingBefore = 3.0;
    
    NSMutableArray *mainStackContent = [[NSMutableArray alloc] init];
    [mainStackContent addObject:nameStack];
    [mainStackContent addObject:_postNode];
    
    if (![_post.media isEqualToString:@""]) {
        CGFloat imageRatio = (_mediaNode.image != nil ? _mediaNode.image.size.height / _mediaNode.image.size.width : 0.5);
        ASRatioLayoutSpec *imagePlace = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:imageRatio child:_mediaNode];
        imagePlace.spacingAfter = 3.0;
        imagePlace.spacingBefore = 3.0;
        
        [mainStackContent addObject:imagePlace];
        
    }
    [mainStackContent addObject:controlsStack];
    
    // Vertical spec of cell main content
    ASStackLayoutSpec *contentSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical spacing:8.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStart children:mainStackContent];
    contentSpec.alignItems = ASStackLayoutAlignSelfStretch;
    contentSpec.flexShrink = YES;
    
    // Horizontal spec for avatar
    ASStackLayoutSpec *avatarContentSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal spacing:8.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStart children:@[_avatarNode, contentSpec]];
    
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 10, 10, 10) child:avatarContentSpec];
    
}

- (void)layout
{
    [super layout];
    
    // Manually layout the divider.
    CGFloat pixelHeight = 1.0f / [[UIScreen mainScreen] scale];
    _divider.frame = CGRectMake(0.0f, 0.0f, self.calculatedSize.width, pixelHeight);
}

#pragma mark - ASTextNodeDelegate methods.

- (BOOL)textNode:(ASTextNode *)richTextNode shouldHighlightLinkAttribute:(NSString *)attribute value:(id)value atPoint:(CGPoint)point
{
    // Opt into link highlighting -- tap and hold the link to try it!  must enable highlighting on a layer, see -didLoad
    return YES;
}

- (void)textNode:(ASTextNode *)richTextNode tappedLinkAttribute:(NSString *)attribute value:(NSURL *)URL atPoint:(CGPoint)point textRange:(NSRange)textRange
{
    // The node tapped a link, open it
    [[UIApplication sharedApplication] openURL:URL];
}

#pragma mark - ASNetworkImageNodeDelegate methods.

- (void)imageNode:(ASNetworkImageNode *)imageNode didLoadImage:(UIImage *)image
{
    [self setNeedsLayout];
}

@end

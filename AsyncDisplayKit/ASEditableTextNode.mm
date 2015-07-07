/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASEditableTextNode.h"

#import <objc/message.h>

#import "ASDisplayNode+Subclasses.h"
#import "ASEqualityHelpers.h"
#import "ASTextNodeTextKitHelpers.h"
#import "ASTextNodeWordKerner.h"
#import "ASThread.h"

//! @abstract This subclass exists solely to ensure the text view's panGestureRecognizer never begins, because it's sporadically enabled by UITextView. It will be removed pending rdar://14729288.
@interface _ASDisabledPanUITextView : UITextView
@end

@implementation _ASDisabledPanUITextView

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  // Never allow our pans to begin.
  if (gestureRecognizer == self.panGestureRecognizer)
    return NO;

  // Otherwise, proceed as usual.
  if ([UITextView instancesRespondToSelector:_cmd])
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
  return YES;
}

@end

#pragma mark -
@interface ASEditableTextNode () <UITextViewDelegate, NSLayoutManagerDelegate>
{
  @private
  // Configuration.
  NSDictionary *_typingAttributes;

  // Core.
  id <ASEditableTextNodeDelegate> __weak _delegate;
  BOOL _delegateDidUpdateEnqueued;

  // TextKit.
  ASDN::RecursiveMutex _textKitLock;
  ASTextKitComponents *_textKitComponents;
  ASTextKitComponents *_placeholderTextKitComponents;
  // Forwards NSLayoutManagerDelegate methods related to word kerning
  ASTextNodeWordKerner *_wordKerner;

  // Misc. State.
  BOOL _displayingPlaceholder; // Defaults to YES.
  BOOL _isPreservingSelection;
  BOOL _selectionChangedForEditedText;
  NSRange _previousSelectedRange;
}

@end

@implementation ASEditableTextNode

#pragma mark - NSObject Overrides
- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _displayingPlaceholder = YES;

  // Create the scaffolding for the text view.
  _textKitComponents = [ASTextKitComponents componentsWithAttributedSeedString:nil textContainerSize:CGSizeZero];
  _textKitComponents.layoutManager.delegate = self;
  _wordKerner = [[ASTextNodeWordKerner alloc] init];

  // Create the placeholder scaffolding.
  _placeholderTextKitComponents = [ASTextKitComponents componentsWithAttributedSeedString:nil textContainerSize:CGSizeZero];
  _placeholderTextKitComponents.layoutManager.delegate = self;

  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)dealloc
{
  _textKitComponents.textView.delegate = nil;
  _textKitComponents.layoutManager.delegate = nil;
  _placeholderTextKitComponents.layoutManager.delegate = nil;
}

#pragma mark - ASDisplayNode Overrides
- (void)didLoad
{
  [super didLoad];

  ASDN::MutexLocker l(_textKitLock);

  void (^configureTextView)(UITextView *) = ^(UITextView *textView) {
    if (!_displayingPlaceholder || textView != _textKitComponents.textView) {
      // If showing the placeholder, don't propagate backgroundColor/opaque to the editable textView.  It is positioned over the placeholder to accept taps to begin editing, and if it's opaque/colored then it'll obscure the placeholder.
      textView.backgroundColor = self.backgroundColor;
      textView.opaque = self.opaque;
    } else if (_displayingPlaceholder && textView == _textKitComponents.textView) {
      // The default backgroundColor for a textView is white.  Due to the reason described above, make sure the editable textView starts out transparent.
      textView.backgroundColor = nil;
      textView.opaque = NO;
    }
    textView.textContainerInset = UIEdgeInsetsZero;
    textView.clipsToBounds = NO; // We don't want selection handles cut off.
  };

  // Create and configure the placeholder text view.
  _placeholderTextKitComponents.textView = [[UITextView alloc] initWithFrame:CGRectZero textContainer:_placeholderTextKitComponents.textContainer];
  _placeholderTextKitComponents.textView.userInteractionEnabled = NO;
  _placeholderTextKitComponents.textView.accessibilityElementsHidden = YES;
  configureTextView(_placeholderTextKitComponents.textView);
  [self.view addSubview:_placeholderTextKitComponents.textView];

  // Create and configure our text view.
  _textKitComponents.textView = [[_ASDisabledPanUITextView alloc] initWithFrame:CGRectZero textContainer:_textKitComponents.textContainer];
  //_textKitComponents.textView = NO; // Unfortunately there's a bug here with iOS 7 DP5 that causes the text-view to only be one line high when scrollEnabled is NO. rdar://14729288
  _textKitComponents.textView.delegate = self;
  _textKitComponents.textView.editable = YES;
  _textKitComponents.textView.typingAttributes = _typingAttributes;
  _textKitComponents.textView.accessibilityHint = _placeholderTextKitComponents.textStorage.string;
  configureTextView(_textKitComponents.textView);
  [self.view addSubview:_textKitComponents.textView];
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASTextKitComponents *displayedComponents = [self isDisplayingPlaceholder] ? _placeholderTextKitComponents : _textKitComponents;
  CGSize textSize = [displayedComponents sizeForConstrainedWidth:constrainedSize.width];
  return CGSizeMake(constrainedSize.width, fminf(textSize.height, constrainedSize.height));
}

- (void)layout
{
  ASDisplayNodeAssertMainThread();

  [self _layoutTextView];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  [super setBackgroundColor:backgroundColor];

  ASDN::MutexLocker l(_textKitLock);

  // If showing the placeholder, don't propagate backgroundColor/opaque to the editable textView.  It is positioned over the placeholder to accept taps to begin editing, and if it's opaque/colored then it'll obscure the placeholder.
  // The backgroundColor/opaque will be propagated to the editable textView when editing begins.
  if (!_displayingPlaceholder) {
    _textKitComponents.textView.backgroundColor = backgroundColor;
  }
  _placeholderTextKitComponents.textView.backgroundColor = backgroundColor;
}

- (void)setOpaque:(BOOL)opaque
{
  [super setOpaque:opaque];

  ASDN::MutexLocker l(_textKitLock);

  // If showing the placeholder, don't propagate backgroundColor/opaque to the editable textView.  It is positioned over the placeholder to accept taps to begin editing, and if it's opaque/colored then it'll obscure the placeholder.
  // The backgroundColor/opaque will be propagated to the editable textView when editing begins.
  if (!_displayingPlaceholder) {
    _textKitComponents.textView.opaque = opaque;
  }
  _placeholderTextKitComponents.textView.opaque = opaque;
}

#pragma mark - Configuration
@synthesize delegate = _delegate;

#pragma mark -
@dynamic typingAttributes;

- (NSDictionary *)typingAttributes
{
  return _typingAttributes;
}

- (void)setTypingAttributes:(NSDictionary *)typingAttributes
{
  if (_typingAttributes == typingAttributes)
    return;

  _typingAttributes = [typingAttributes copy];

  ASDN::MutexLocker l(_textKitLock);

  _textKitComponents.textView.typingAttributes = _typingAttributes;
}

#pragma mark -
@dynamic selectedRange;

- (NSRange)selectedRange
{
  ASDN::MutexLocker l(_textKitLock);
  return _textKitComponents.textView.selectedRange;
}

- (void)setSelectedRange:(NSRange)selectedRange
{
  ASDN::MutexLocker l(_textKitLock);
  _textKitComponents.textView.selectedRange = selectedRange;
}

#pragma mark - Placeholder
- (BOOL)isDisplayingPlaceholder
{
  return _displayingPlaceholder;
}

#pragma mark -
@dynamic attributedPlaceholderText;
- (NSAttributedString *)attributedPlaceholderText
{
  ASDN::MutexLocker l(_textKitLock);

  return [_placeholderTextKitComponents.textStorage copy];
}

- (void)setAttributedPlaceholderText:(NSAttributedString *)attributedPlaceholderText
{
  ASDN::MutexLocker l(_textKitLock);

  if (ASObjectIsEqual(_placeholderTextKitComponents.textStorage, attributedPlaceholderText))
    return;

  [_placeholderTextKitComponents.textStorage setAttributedString:attributedPlaceholderText ?: [[NSAttributedString alloc] initWithString:@""]];
  _textKitComponents.textView.accessibilityHint = attributedPlaceholderText.string;
}

#pragma mark - Modifying User Text
@dynamic attributedText;
- (NSAttributedString *)attributedText
{
  // Per contract in our header, this value is nil when the placeholder is displayed.
  if ([self isDisplayingPlaceholder])
    return nil;

  ASDN::MutexLocker l(_textKitLock);

  return [_textKitComponents.textStorage copy];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
  ASDN::MutexLocker l(_textKitLock);

  // If we (_cmd) are called while the text view itself is updating (-textViewDidUpdate:), you cannot update the text storage and expect perfect propagation to the text view.
  // Thus, we always update the textview directly if it's been created already.
  if (ASObjectIsEqual((_textKitComponents.textView.attributedText ?: _textKitComponents.textStorage), attributedText))
    return;

  // If the cursor isn't at the end of the text, we need to preserve the selected range to avoid moving the cursor.
  NSRange selectedRange = _textKitComponents.textView.selectedRange;
  BOOL preserveSelectedRange = (selectedRange.location != _textKitComponents.textStorage.length);

  NSAttributedString *attributedStringToDisplay = nil;

  if (attributedText)
    attributedStringToDisplay = attributedText;
  // Otherwise, note that we don't simply nil out attributed text. Because the insertion point is guided by the attributes at index 0, we need to attribute an empty string to ensure the insert point obeys our typing attributes.
  else
    attributedStringToDisplay = [[NSAttributedString alloc] initWithString:@"" attributes:self.typingAttributes];

  // Always prefer updating the text view directly if it's been created (see above).
  if (_textKitComponents.textView)
    [_textKitComponents.textView setAttributedText:attributedStringToDisplay];
  else
    [_textKitComponents.textStorage setAttributedString:attributedStringToDisplay];

  // Calculated size depends on the seeded text.
  [self invalidateCalculatedLayout];

  // Update if placeholder is shown.
  [self _updateDisplayingPlaceholder];

  // Preserve cursor range, if necessary.
  if (preserveSelectedRange) {
    _isPreservingSelection = YES; // Used in -textViewDidChangeSelection: to avoid informing our delegate about our preservation.
    [_textKitComponents.textView setSelectedRange:selectedRange];
    _isPreservingSelection = NO;
  }
}

#pragma mark - Core
- (void)_updateDisplayingPlaceholder
{
  ASDN::MutexLocker l(_textKitLock);

  // Show the placeholder if necessary.
  _displayingPlaceholder = (_textKitComponents.textStorage.length == 0);
  _placeholderTextKitComponents.textView.hidden = !_displayingPlaceholder;

  // If hiding the placeholder, propagate backgroundColor/opaque to the editable textView.  It is positioned over the placeholder to accept taps to begin editing, and was kept transparent so it doesn't obscure the placeholder text.  Now that we're editing it and the placeholder is hidden, we can make it opaque to avoid unnecessary blending.
  if (!_displayingPlaceholder) {
    _textKitComponents.textView.opaque = self.isOpaque;
    _textKitComponents.textView.backgroundColor = self.backgroundColor;
  } else {
    _textKitComponents.textView.opaque = NO;
    _textKitComponents.textView.backgroundColor = nil;
  }
}

- (void)_layoutTextView
{
  ASDN::MutexLocker l(_textKitLock);

  // Layout filling our bounds.
  _textKitComponents.textView.frame = self.bounds;
  _placeholderTextKitComponents.textView.frame = self.bounds;

  // Note that both of these won't be necessary once we can disable scrolling, pending rdar://14729288
  // When we resize to fit (above) the prior layout becomes invalid. For whatever reason, UITextView doesn't invalidate its layout when its frame changes on its own, so we have to do so ourselves.
  [_textKitComponents.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, [_textKitComponents.textStorage length]) actualCharacterRange:NULL];

  // When you type beyond UITextView's bounds it scrolls you down a line. We need to remain at the top.
  [_textKitComponents.textView setContentOffset:CGPointZero animated:NO];
}

#pragma mark - Keyboard
@dynamic textInputMode;
- (UITextInputMode *)textInputMode
{
  ASDN::MutexLocker l(_textKitLock);
  return [_textKitComponents.textView textInputMode];
}

- (BOOL)isFirstResponder
{
  ASDN::MutexLocker l(_textKitLock);
  return [_textKitComponents.textView isFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    ASDN::MutexLocker l(_textKitLock);
    return [_textKitComponents.textView canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder
{
  ASDN::MutexLocker l(_textKitLock);
  return [_textKitComponents.textView becomeFirstResponder];
}

- (BOOL)canResignFirstResponder {
    ASDN::MutexLocker l(_textKitLock);
    return [_textKitComponents.textView canResignFirstResponder];
}

- (BOOL)resignFirstResponder
{
  ASDN::MutexLocker l(_textKitLock);
  return [_textKitComponents.textView resignFirstResponder];
}

#pragma mark - UITextView Delegate
- (void)textViewDidBeginEditing:(UITextView *)textView
{
  // Delegateify.
  [self _delegateDidBeginEditing];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  // Delegateify.
  return [self _delegateShouldChangeTextInRange:range replacementText:text];
}

- (void)textViewDidChange:(UITextView *)textView
{
  ASDN::MutexLocker l(_textKitLock);

  // Note we received a text changed event.
  // This is used by _delegateDidChangeSelectionFromSelectedRange:toSelectedRange: to distinguish between selection changes that happen because of editing or pure selection changes.
  _selectionChangedForEditedText = YES;

  // Update if the placeholder is visible.
  [self _updateDisplayingPlaceholder];

  // Invalidate, as our calculated size depends on the textview's seeded text.
  [self invalidateCalculatedLayout];

  // Delegateify.
  [self _delegateDidUpdateText];
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
  // Typing attributes get reset when selection changes. Reapply them so they actually obey our header.
  _textKitComponents.textView.typingAttributes = _typingAttributes;

  // If we're only changing selection to preserve it, don't notify about anything.
  if (_isPreservingSelection)
    return;

  // Note if we receive a -textDidChange: between now and when we delegatify.
  // This is used by _delegateDidChangeSelectionFromSelectedRange:toSelectedRange: to distinguish between selection changes that happen because of editing or pure selection changes.
  _selectionChangedForEditedText = NO;

  NSRange fromSelectedRange = _previousSelectedRange;
  NSRange toSelectedRange = self.selectedRange;
  _previousSelectedRange = toSelectedRange;

  // Delegateify.
  [self _delegateDidChangeSelectionFromSelectedRange:fromSelectedRange toSelectedRange:toSelectedRange];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
  // Delegateify.
  [self _delegateDidFinishEditing];
}

#pragma mark - NSLayoutManager Delegate

- (NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)properties characterIndexes:(const NSUInteger *)characterIndexes font:(UIFont *)aFont forGlyphRange:(NSRange)glyphRange
{
  return [_wordKerner layoutManager:layoutManager shouldGenerateGlyphs:glyphs properties:properties characterIndexes:characterIndexes font:aFont forGlyphRange:glyphRange];
}

- (NSControlCharacterAction)layoutManager:(NSLayoutManager *)layoutManager shouldUseAction:(NSControlCharacterAction)defaultAction forControlCharacterAtIndex:(NSUInteger)characterIndex
{
  return [_wordKerner layoutManager:layoutManager shouldUseAction:defaultAction forControlCharacterAtIndex:characterIndex];
}

- (CGRect)layoutManager:(NSLayoutManager *)layoutManager boundingBoxForControlGlyphAtIndex:(NSUInteger)glyphIndex forTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)proposedRect glyphPosition:(CGPoint)glyphPosition characterIndex:(NSUInteger)characterIndex
{
  return [_wordKerner layoutManager:layoutManager boundingBoxForControlGlyphAtIndex:glyphIndex forTextContainer:textContainer proposedLineFragment:proposedRect glyphPosition:glyphPosition characterIndex:characterIndex];
}

#pragma mark - Geometry
- (CGRect)frameForTextRange:(NSRange)textRange
{
  ASDN::MutexLocker l(_textKitLock);

  // Bail on invalid range.
  if (NSMaxRange(textRange) > [_textKitComponents.textStorage length]) {
    ASDisplayNodeAssert(NO, @"Invalid range");
    return CGRectZero;
  }

  // Force glyph generation and layout.
  [_textKitComponents.layoutManager ensureLayoutForTextContainer:_textKitComponents.textContainer];

  NSRange glyphRange = [_textKitComponents.layoutManager glyphRangeForCharacterRange:textRange actualCharacterRange:NULL];
  CGRect textRect = [_textKitComponents.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textKitComponents.textContainer];
  return [_textKitComponents.textView convertRect:textRect toView:self.view];
}

#pragma mark -
- (void)_delegateDidBeginEditing
{
  if ([_delegate respondsToSelector:@selector(editableTextNodeDidBeginEditing:)])
    [_delegate editableTextNodeDidBeginEditing:self];
}

- (BOOL)_delegateShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  if ([_delegate respondsToSelector:@selector(editableTextNode:shouldChangeTextInRange:replacementText:)]) {
    return [_delegate editableTextNode:self shouldChangeTextInRange:range replacementText:text];
  }

  return YES;
}

- (void)_delegateDidChangeSelectionFromSelectedRange:(NSRange)fromSelectedRange toSelectedRange:(NSRange)toSelectedRange
{
  // There are two reasons we're invoking the delegate on the next run of the runloop.
  // 1. UITextView invokes its delegate methods when it's in the middle of text-processing. For example, -textViewDidChange: is invoked before you can truly rely on the changes being propagated throughout the Text Kit hierarchy.
  // 2. This delegate method (-textViewDidChangeSelection:) is called both before -textViewDidChange: and before the layout manager/etc. has necessarily generated+laid out its glyphs. Because of the former, we need to wait until -textViewDidChange: has had an opportunity to be called so can accurately determine whether this selection change is due to editing (_selectionChangedForEditedText).
  // Thus, to avoid calling out to client code in the middle of UITextView's processing, we call the delegate on the next run of the runloop, when all such internal processing is surely done.
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([_delegate respondsToSelector:@selector(editableTextNodeDidChangeSelection:fromSelectedRange:toSelectedRange:dueToEditing:)])
      [_delegate editableTextNodeDidChangeSelection:self fromSelectedRange:fromSelectedRange toSelectedRange:toSelectedRange dueToEditing:_selectionChangedForEditedText];
  });
}

- (void)_delegateDidUpdateText
{
  // Note that because -editableTextNodeDidUpdateText: passes no state, the current state of the receiver will be accessed. Thus, it's not useful to enqueue a second delegation call if the first hasn't happened yet -- doing so will result in the delegate receiving -editableTextNodeDidUpdateText: when the "updated text" has already been processed. This may sound innocuous, but because our delegation may cause additional updates to the textview's string, and because such updates discard spelling suggestions and autocompletions (like double-space to `.`), it can actually be quite dangerous!
  if (_delegateDidUpdateEnqueued)
    return;

  _delegateDidUpdateEnqueued = YES;

  // UITextView invokes its delegate methods when it's in the middle of text-processing. For example, -textViewDidChange: is invoked before you can truly rely on the changes being propagated throughout the Text Kit hierarchy.
  // Thus, to avoid calling out to client code in the middle of UITextView's processing, we call the delegate on the next run of the runloop, when all such internal processing is surely done.
  dispatch_async(dispatch_get_main_queue(), ^{
    _delegateDidUpdateEnqueued = NO;
    if ([_delegate respondsToSelector:@selector(editableTextNodeDidUpdateText:)])
      [_delegate editableTextNodeDidUpdateText:self];
  });
}

- (void)_delegateDidFinishEditing
{
  if ([_delegate respondsToSelector:@selector(editableTextNodeDidFinishEditing:)])
    [_delegate editableTextNodeDidFinishEditing:self];
}

@end

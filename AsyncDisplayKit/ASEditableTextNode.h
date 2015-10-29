/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASDisplayNode.h>


@protocol ASEditableTextNodeDelegate;

/**
 @abstract Implements a node that supports text editing.
 @discussion Does not support layer backing.
 */
@interface ASEditableTextNode : ASDisplayNode

// @abstract The text node's delegate, which must conform to the <ASEditableTextNodeDelegate> protocol.
@property (nonatomic, readwrite, weak) id <ASEditableTextNodeDelegate> delegate;

#pragma mark - Configuration

/**
  @abstract Access to underlying UITextView for more configuration options.
  @warning This property should only be used on the main thread and should not be accessed before the editable text node's view is created.
 */
@property (nonatomic, readonly, strong) UITextView *textView;

//! @abstract The attributes to apply to new text being entered by the user.
@property (nonatomic, readwrite, strong) NSDictionary *typingAttributes;

//! @abstract The range of text currently selected. If length is zero, the range is the cursor location.
@property (nonatomic, readwrite, assign) NSRange selectedRange;

#pragma mark - Placeholder
/**
  @abstract Indicates if the receiver is displaying the placeholder text.
  @discussion To update the placeholder, see the <attributedPlaceholderText> property.
  @result YES if the placeholder is currently displayed; NO otherwise.
 */
- (BOOL)isDisplayingPlaceholder;

/**
  @abstract The styled placeholder text displayed by the text node while no text is entered
  @discussion The placeholder is displayed when the user has not entered any text and the keyboard is not visible.
 */
@property (nonatomic, readwrite, strong) NSAttributedString *attributedPlaceholderText;

#pragma mark - Modifying User Text
/**
  @abstract The styled text displayed by the receiver.
  @discussion When the placeholder is displayed (as indicated by -isDisplayingPlaceholder), this value is nil. Otherwise, this value is the attributed text the user has entered. This value can be modified regardless of whether the receiver is the first responder (and thus, editing) or not. Changing this value from nil to non-nil will result in the placeholder being hidden, and the new value being displayed.
 */
@property (nonatomic, readwrite, copy) NSAttributedString *attributedText;

#pragma mark - Managing The Keyboard
//! @abstract The text input mode used by the receiver's keyboard, if it is visible. This value is undefined if the receiver is not the first responder.
@property (nonatomic, readonly) UITextInputMode *textInputMode;

/*
 @abstract The textContainerInset of both the placeholder and typed textView. This value defaults to UIEdgeInsetsZero.
 */
@property (nonatomic, readwrite) UIEdgeInsets textContainerInset;

/*
 @abstract The returnKeyType of the keyboard. This value defaults to UIReturnKeyDefault.
 */
@property (nonatomic, readwrite) UIReturnKeyType returnKeyType;

/**
  @abstract Indicates whether the receiver's text view is the first responder, and thus has the keyboard visible and is prepared for editing by the user.
  @result YES if the receiver's text view is the first-responder; NO otherwise.
 */
- (BOOL)isFirstResponder;

//! @abstract Makes the receiver's text view the first responder.
- (BOOL)becomeFirstResponder;

//! @abstract Resigns the receiver's text view from first-responder status, if it has it.
- (BOOL)resignFirstResponder;

#pragma mark - Geometry
/**
  @abstract Returns the frame of the given range of characters.
  @param textRange A range of characters.
  @discussion This method raises an exception if `textRange` is not a valid range of characters within the receiver's attributed text.
  @result A CGRect that is the bounding box of the glyphs covered by the given range of characters, in the coordinate system of the receiver.
 */
- (CGRect)frameForTextRange:(NSRange)textRange;

@end

#pragma mark -
/**
 * The methods declared by the ASEditableTextNodeDelegate protocol allow the adopting delegate to 
 * respond to notifications such as began and finished editing, selection changed and text updated;
 * and manage whether a specified text should be replaced.
 */
@protocol ASEditableTextNodeDelegate <NSObject>

@optional
/**
  @abstract Indicates to the delegate that the text node began editing.
  @param editableTextNode An editable text node.
  @discussion The invocation of this method coincides with the keyboard animating to become visible.
 */
- (void)editableTextNodeDidBeginEditing:(ASEditableTextNode *)editableTextNode;

/**
  @abstract Asks the delegate whether the specified text should be replaced in the editable text node.
  @param editableTextNode An editable text node.
  @param range The current selection range. If the length of the range is 0, range reflects the current insertion point. If the user presses the Delete key, the length of the range is 1 and an empty string object replaces that single character.
  @param text The text to insert.
  @discussion YES if the old text should be replaced by the new text; NO if the replacement operation should be aborted.
  @result The text node calls this method whenever the user types a new character or deletes an existing character. Implementation of this method is optional -- the default implementation returns YES.
 */
- (BOOL)editableTextNode:(ASEditableTextNode *)editableTextNode shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;

/**
  @abstract Indicates to the delegate that the text node's selection has changed.
  @param editableTextNode An editable text node.
  @param fromSelectedRange The previously selected range.
  @param toSelectedRange The current selected range. Equvialent to the <selectedRange> property.
  @param dueToEditing YES if the selection change was due to editing; NO otherwise.
  @discussion You can access the selection of the receiver via <selectedRange>.
 */
- (void)editableTextNodeDidChangeSelection:(ASEditableTextNode *)editableTextNode fromSelectedRange:(NSRange)fromSelectedRange toSelectedRange:(NSRange)toSelectedRange dueToEditing:(BOOL)dueToEditing;

/**
  @abstract Indicates to the delegate that the text node's text was updated.
  @param editableTextNode An editable text node.
  @discussion This method is called each time the user updated the text node's text. It is not called for programmatic changes made to the text via the <attributedText> property.
 */
- (void)editableTextNodeDidUpdateText:(ASEditableTextNode *)editableTextNode;

/**
  @abstract Indicates to the delegate that teh text node has finished editing.
  @param editableTextNode An editable text node.
  @discussion The invocation of this method coincides with the keyboard animating to become hidden.
 */
- (void)editableTextNodeDidFinishEditing:(ASEditableTextNode *)editableTextNode;


@end

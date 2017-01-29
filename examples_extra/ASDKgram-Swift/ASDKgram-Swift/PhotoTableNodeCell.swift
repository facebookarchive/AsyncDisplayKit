//
//  PhotoTableNodeCell.swift
//  ASDKgram-Swift
//
//  Created by Calum Harris on 09/01/2017.
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
//   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.//

import Foundation
import AsyncDisplayKit

class PhotoTableNodeCell: ASCellNode {
	
	let usernameLabel = ASTextNode()
	let timeIntervalLabel = ASTextNode()
	let photoLikesLabel = ASTextNode()
	let photoDescriptionLabel = ASTextNode()
	
	let avatarImageNode: ASNetworkImageNode = {
		let imageNode = ASNetworkImageNode()
		imageNode.contentMode = .scaleAspectFill
		imageNode.imageModificationBlock = ASImageNodeRoundBorderModificationBlock(0, nil)
		return imageNode
	}()
	
	let photoImageNode: ASNetworkImageNode = {
		let imageNode = ASNetworkImageNode()
		imageNode.contentMode = .scaleAspectFill
		return imageNode
	}()
	
	init(photoModel: PhotoModel) {
		super.init()
		self.photoImageNode.url = URL(string: photoModel.url)
		self.avatarImageNode.url = URL(string: photoModel.ownerPicURL)
		self.usernameLabel.attributedText = photoModel.attrStringForUserName(withSize: Constants.CellLayout.FontSize)
		self.timeIntervalLabel.attributedText = photoModel.attrStringForTimeSinceString(withSize: Constants.CellLayout.FontSize)
		self.photoLikesLabel.attributedText = photoModel.attrStringLikes(withSize: Constants.CellLayout.FontSize)
		self.photoDescriptionLabel.attributedText = photoModel.attrStringForDescription(withSize: Constants.CellLayout.FontSize)
		self.automaticallyManagesSubnodes = true
	}
	
	override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
		
		// Header Stack
		
		var headerChildren: [ASLayoutElement] = []
		
		let headerStack = ASStackLayoutSpec.horizontal()
		headerStack.alignItems = .center
		avatarImageNode.style.preferredSize = CGSize(width: Constants.CellLayout.UserImageHeight, height: Constants.CellLayout.UserImageHeight)
		headerChildren.append(ASInsetLayoutSpec(insets: Constants.CellLayout.InsetForAvatar, child: avatarImageNode))
		usernameLabel.style.flexShrink = 1.0
		headerChildren.append(usernameLabel)
		
		let spacer = ASLayoutSpec()
		spacer.style.flexGrow = 1.0
		headerChildren.append(spacer)
		
		timeIntervalLabel.style.spacingBefore = Constants.CellLayout.HorizontalBuffer
		headerChildren.append(timeIntervalLabel)
		
		let footerStack = ASStackLayoutSpec.vertical()
		footerStack.spacing = Constants.CellLayout.VerticalBuffer
		footerStack.children = [photoLikesLabel, photoDescriptionLabel]
		headerStack.children = headerChildren
		
		let verticalStack = ASStackLayoutSpec.vertical()
		
		verticalStack.children = [ASInsetLayoutSpec(insets: Constants.CellLayout.InsetForHeader, child: headerStack), ASRatioLayoutSpec(ratio: 1.0, child: photoImageNode), ASInsetLayoutSpec(insets: Constants.CellLayout.InsetForFooter, child: footerStack)]
		
		return verticalStack
	}
}

//
//  PhotoModel.swift
//  ASDKgram-Swift
//
//  Created by Calum Harris on 07/01/2017.
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
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import UIKit

typealias JSONDictionary = [String : Any]

struct PhotoModel {
	
	let url: String
	let photoID: Int
	let dateString: String
	let descriptionText: String
	let likesCount: Int
	let ownerUserName: String
	let ownerPicURL: String
	
	init?(dictionary: JSONDictionary) {
		
		guard let url = dictionary["image_url"] as? String, let date = dictionary["created_at"] as? String, let photoID = dictionary["id"] as? Int, let descriptionText = dictionary["name"] as? String, let likesCount = dictionary["positive_votes_count"] as? Int else { print("error parsing JSON within PhotoModel Init"); return nil }
		
		guard let user = dictionary["user"] as? JSONDictionary, let username = user["username"] as? String, let ownerPicURL = user["userpic_url"] as? String else { print("error parsing JSON within PhotoModel Init"); return nil }
		
		self.url = url
		self.photoID = photoID
		self.descriptionText = descriptionText
		self.likesCount = likesCount
		self.dateString = date
		self.ownerUserName = username
		self.ownerPicURL = ownerPicURL
	}
}

extension PhotoModel {
	
	// MARK: - Attributed Strings
	
	func attrStringForUserName(withSize size: CGFloat) -> NSAttributedString {
		let attr = [
			NSForegroundColorAttributeName : UIColor.darkGray,
			NSFontAttributeName: UIFont.boldSystemFont(ofSize: size)
		]
		return NSAttributedString(string: self.ownerUserName, attributes: attr)
	}
	
	func attrStringForDescription(withSize size: CGFloat) -> NSAttributedString {
		let attr = [
			NSForegroundColorAttributeName : UIColor.darkGray,
			NSFontAttributeName: UIFont.systemFont(ofSize: size)
		]
		return NSAttributedString(string: self.descriptionText, attributes: attr)
	}
	
	func attrStringLikes(withSize size: CGFloat) -> NSAttributedString {
		
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		let formattedLikesNumber: String? = formatter.string(from: NSNumber(value: self.likesCount))
		let likesString: String = "\(formattedLikesNumber!) Likes"
		let textAttr = [NSForegroundColorAttributeName : UIColor.mainBarTintColor(), NSFontAttributeName: UIFont.systemFont(ofSize: size)]
		let likesAttrString = NSAttributedString(string: likesString, attributes: textAttr)
		
		let heartAttr = [NSForegroundColorAttributeName : UIColor.red, NSFontAttributeName: UIFont.systemFont(ofSize: size)]
		let heartAttrString = NSAttributedString(string: "♥︎ ", attributes: heartAttr)
		
		let combine = NSMutableAttributedString()
		combine.append(heartAttrString)
		combine.append(likesAttrString)
		return combine
	}
	
	func attrStringForTimeSinceString(withSize size: CGFloat) -> NSAttributedString {
		
		let attr = [
			NSForegroundColorAttributeName : UIColor.mainBarTintColor(),
			NSFontAttributeName: UIFont.systemFont(ofSize: size)
		]
		
		let date = Date.iso8601Formatter.date(from: self.dateString)!
		return NSAttributedString(string: timeStringSince(fromConverted: date), attributes: attr)
	}
	
	private func timeStringSince(fromConverted date: Date) -> String {
		let diffDates = NSCalendar.current.dateComponents([.day, .hour, .second], from: date, to: Date())
		
		if let week = diffDates.day, week > 7 {
			return "\(week / 7)w"
		} else if let day = diffDates.day, day > 0 {
			return "\(day)d"
		} else if let hour = diffDates.hour, hour > 0 {
			return "\(hour)h"
		} else if let second = diffDates.second, second > 0 {
			return "\(second)s"
		} else if let zero = diffDates.second, zero == 0 {
			return "1s"
		} else {
			return "ERROR"
		}
	}
}

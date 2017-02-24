//
//  PhotoFeedModel.swift
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

final class PhotoFeedModel {

	public private(set) var photoFeedModelType: PhotoFeedModelType
	public private(set) var photos: [PhotoModel] = []
	public private(set) var imageSize: CGSize
	private var url: URL
	private var ids: [Int] = []
	private var currentPage: Int = 0
	private var totalPages: Int = 0
	public private(set) var totalItems: Int = 0
	private var fetchPageInProgress: Bool = false
	private var refreshFeedInProgress: Bool = false

	init(initWithPhotoFeedModelType: PhotoFeedModelType, requiredImageSize: CGSize) {
		self.photoFeedModelType = initWithPhotoFeedModelType
		self.imageSize = requiredImageSize
		self.url = URL.URLForFeedModelType(feedModelType: initWithPhotoFeedModelType)
	}

	var numberOfItemsInFeed: Int {
		return photos.count
	}

	// return in completion handler the number of additions and the status of internet connection

	func updateNewBatchOfPopularPhotos(additionsAndConnectionStatusCompletion: @escaping (Int, InternetStatus) -> ()) {

		guard !fetchPageInProgress else { return }

		fetchPageInProgress = true
		fetchNextPageOfPopularPhotos(replaceData: false) { [unowned self] additions, errors in
			self.fetchPageInProgress = false

			if let error = errors {
				switch error {
				case .noInternetConnection:
				additionsAndConnectionStatusCompletion(0, .noConnection)
				default: additionsAndConnectionStatusCompletion(0, .connected)
				}
			} else {
				additionsAndConnectionStatusCompletion(additions, .connected)
			}
		}
	}

	private func fetchNextPageOfPopularPhotos(replaceData: Bool, numberOfAdditionsCompletion: @escaping (Int, NetworkingErrors?) -> ()) {

		if currentPage == totalPages, currentPage != 0 {
			return numberOfAdditionsCompletion(0, .customError("No pages left to parse"))
		}

		var newPhotos: [PhotoModel] = []
		var newIDs: [Int] = []

		let pageToFetch = currentPage + 1

		let url = self.url.addImageParameterForClosestImageSizeAndpage(size: imageSize, page: pageToFetch)

		WebService().load(resource: parsePopularPage(withURL: url)) { [unowned self] result in

			switch result {
				case .success(let popularPage):
				self.totalItems = popularPage.totalNumberOfItems
				self.totalPages = popularPage.totalPages
				self.currentPage = popularPage.page

				for photo in popularPage.photos {
					if !replaceData || !self.ids.contains(photo.photoID) {
						newPhotos.append(photo)
						newIDs.append(photo.photoID)
					}
				}

				DispatchQueue.main.async {
					if replaceData {
						self.photos = newPhotos
						self.ids = newIDs
					} else {
						self.photos += newPhotos
						self.ids += newIDs
					}

					numberOfAdditionsCompletion(newPhotos.count, nil)
				}

				case .failure(let fail):
				print(fail)
				numberOfAdditionsCompletion(0, fail)
			}
		}
	}
}

enum PhotoFeedModelType {
	case photoFeedModelTypePopular
	case photoFeedModelTypeLocation
	case photoFeedModelTypeUserPhotos
}

enum InternetStatus {
	case connected
	case noConnection
}

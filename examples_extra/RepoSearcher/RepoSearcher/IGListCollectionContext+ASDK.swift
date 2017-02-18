//
//  IGListCollectionContext+ASDK.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import Foundation
import IGListKit
import AsyncDisplayKit

extension IGListCollectionContext {
    func nodeForItem(at index: Int, sectionController: IGListSectionController) -> ASCellNode? {
        return (cellForItem(at: index, sectionController: sectionController) as? _ASCollectionViewCell)?.node
    }
}

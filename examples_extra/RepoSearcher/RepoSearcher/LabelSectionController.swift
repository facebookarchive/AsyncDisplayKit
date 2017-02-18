//
//  LabelSectionController.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import Foundation
import AsyncDisplayKit
import IGListKit

final class LabelSectionController: IGListSectionController, IGListSectionType, ASSectionController {
    var object: String?

    func nodeBlockForItem(at index: Int) -> ASCellNodeBlock {
        let text = object ?? ""
        return {
            let node = ASTextCellNode()
            node.text = text
            return node
        }
    }
    
    func numberOfItems() -> Int {
        return 1
    }
    
    func didUpdate(to object: Any) {
        self.object = String(describing: object)
    }
    
    func didSelectItem(at index: Int) {
        
    }
    
    func sizeForItem(at index: Int) -> CGSize {
        assert(true, "Did not expect to be called.")
        return .zero
    }
    
    func cellForItem(at index: Int) -> UICollectionViewCell {
        return collectionContext!.dequeueReusableCell(of: _ASCollectionViewCell.self, for: self, at: index)
    }
}

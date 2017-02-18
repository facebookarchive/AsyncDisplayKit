//
//  IGListSectionType+ASDK.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import IGListKit
import AsyncDisplayKit

extension IGListSectionController {
    func ASIGSectionControllerCellForIndexImplementation(index: Int) -> UICollectionViewCell {
        return collectionContext!.dequeueReusableCell(of: _ASCollectionViewCell.self, for: self, at: index)
    }
    
    func ASIGSectionControllerSizeForItemImplementation() -> CGSize {
        return .zero
    }
    
    func ASIGSupplementarySourceSizeForSupplementaryElementImplementation() -> CGSize {
        return .zero
    }
    
    func ASIGSupplementarySourceViewForSupplementaryElementImplementation(ofKind elementKind: String, at index: Int) -> UICollectionReusableView {
        return collectionContext!.dequeueReusableSupplementaryView(ofKind: elementKind, for: self, class: UICollectionReusableView.self, at: index)
    }
}

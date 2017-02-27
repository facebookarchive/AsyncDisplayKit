//
//  SearchSectionController.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import AsyncDisplayKit
import IGListKit

protocol SearchSectionControllerDelegate: class {
    func searchSectionController(_ sectionController: SearchSectionController, didChangeText text: String)
}

final class SearchSectionController: IGListSectionController, IGListSectionType, ASSectionController {
    
    weak var delegate: SearchSectionControllerDelegate?

    override init() {
        super.init()
        scrollDelegate = self
    }
    
    func nodeBlockForItem(at index: Int) -> ASCellNodeBlock {
        return { [weak self] in
            return SearchNode(delegate: self)
        }
    }
    
    func numberOfItems() -> Int {
        return 1
    }
    
    func didUpdate(to object: Any) {}
    func didSelectItem(at index: Int) {}
    
    //ASDK Replacement
    func sizeForItem(at index: Int) -> CGSize {
        return ASIGListSectionControllerMethods.sizeForItem(at: index)
    }
    
    func cellForItem(at index: Int) -> UICollectionViewCell {
        return ASIGListSectionControllerMethods.cellForItem(at: index, sectionController: self)
    }
}

extension SearchSectionController: IGListScrollDelegate {
    func listAdapter(_ listAdapter: IGListAdapter, didScroll sectionController: IGListSectionController) {
        guard let searchNode = collectionContext?.nodeForItem(at: 0, sectionController: self) as? SearchNode else { return }
        
        let searchBar = searchNode.searchBarNode.searchBar
        searchBar.text = ""
        searchBar.resignFirstResponder()
    }
    
    func listAdapter(_ listAdapter: IGListAdapter!, willBeginDragging sectionController: IGListSectionController!) {}
    func listAdapter(_ listAdapter: IGListAdapter!, didEndDragging sectionController: IGListSectionController!, willDecelerate decelerate: Bool) {}

}

extension SearchSectionController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        delegate?.searchSectionController(self, didChangeText: searchText)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        delegate?.searchSectionController(self, didChangeText: "")
    }
}


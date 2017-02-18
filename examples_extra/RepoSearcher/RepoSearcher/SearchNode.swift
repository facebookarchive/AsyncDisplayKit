//
//  SearchNode.swift
//  RepoSearcher
//
//  Created by Marvin Nazari on 2017-02-18.
//  Copyright © 2017 Marvin Nazari. All rights reserved.
//

import Foundation
import AsyncDisplayKit

class SearchNode: ASCellNode {
    var searchBarNode: SearchBarNode
    
    init(delegate: UISearchBarDelegate?) {
        self.searchBarNode = SearchBarNode(delegate: delegate)
        super.init()
        automaticallyManagesSubnodes = true
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: .zero, child: searchBarNode)
    }
}

final class SearchBarNode: ASDisplayNode {
    
    weak var delegate: UISearchBarDelegate?
    
    init(delegate: UISearchBarDelegate?) {
        self.delegate = delegate
        super.init(viewBlock: {
            UISearchBar()
        }, didLoad: nil)
        style.preferredSize = CGSize(width: UIScreen.main.bounds.width, height: 44)
    }
    
    var searchBar: UISearchBar {
        return view as! UISearchBar
    }
    
    override func didLoad() {
        super.didLoad()
        searchBar.delegate = delegate
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = .black
        searchBar.backgroundColor = .white
        searchBar.placeholder = "Search"
    }
}

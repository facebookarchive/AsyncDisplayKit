//
//  DemoCellNode.swift
//  BackgroundPropertySetting
//
//  Created by Adlai Holler on 2/17/16.
//  Copyright © 2016 Adlai Holler. All rights reserved.
//

import UIKit
import AsyncDisplayKit

final class DemoCellNode: ASCellNode {
	let childA = ASDisplayNode()
	let childB = ASDisplayNode()
	var state = State.Right

	override init() {
		super.init()
		usesImplicitHierarchyManagement = true
	}

	override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {
		let specA = ASRatioLayoutSpec(ratio: 1, child: childA)
		specA.flexBasis = ASRelativeDimensionMakeWithPoints(1)
		specA.flexGrow = true
		let specB = ASRatioLayoutSpec(ratio: 1, child: childB)
		specB.flexBasis = ASRelativeDimensionMakeWithPoints(1)
		specB.flexGrow = true
		let children = state.isReverse ? [ specB, specA ] : [ specA, specB ]
		let direction: ASStackLayoutDirection = state.isVertical ? .Vertical : .Horizontal
		return ASStackLayoutSpec(direction: direction,
			spacing: 20,
			justifyContent: .SpaceAround,
			alignItems: .Center,
			children: children)
	}

	override func animateLayoutTransition(context: ASContextTransitioning!) {
		childA.frame = context.initialFrameForNode(childA)
		childB.frame = context.initialFrameForNode(childB)
		let tinyDelay = drand48() / 10
		UIView.animateWithDuration(0.5, delay: tinyDelay, usingSpringWithDamping: 0.9, initialSpringVelocity: 1.5, options: .BeginFromCurrentState, animations: { () -> Void in
				self.childA.frame = context.finalFrameForNode(self.childA)
				self.childB.frame = context.finalFrameForNode(self.childB)
			}, completion: {
				context.completeTransition($0)
		})
	}

	enum State {
		case Right
		case Up
		case Left
		case Down

		var isVertical: Bool {
			switch self {
			case .Up, .Down:
				return true
			default:
				return false
			}
		}

		var isReverse: Bool {
			switch self {
			case .Left, .Up:
				return true
			default:
				return false
			}
		}

		mutating func advance() {
			switch self {
			case .Right:
				self = .Up
			case .Up:
				self = .Left
			case .Left:
				self = .Down
			case .Down:
				self = .Right
			}
		}
	}
}

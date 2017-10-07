//
//  NavigationTreeDiff.swift
//  KatanaRouter
//
//  Created by Michal Ciurus on 15/02/17.
//  Copyright © 2017 Michal Ciurus. All rights reserved.
//

import Foundation

enum NavigationTreeDiffAction<ViewController: AnyObject> {
  case push(nodeToPush: NavigationTreeNode<ViewController>)
  case pop(nodeToPop: NavigationTreeNode<ViewController>)
  case changed(poppedNodes: [NavigationTreeNode<ViewController>], pushedNodes: [NavigationTreeNode<ViewController>])
  case changedActiveChild(child: NavigationTreeNode<ViewController>)
  case selectedActiveChild(child: NavigationTreeNode<ViewController>)
}

class NavigationTreeDiff<ViewController: AnyObject> {
  
  /// Returns an array of actions, which are the differences between lastState and currentState
  /// This method **does not change the state of the trees in any way**
  /// - Parameters:
  ///   - lastState: last state tree
  ///   - currentState: current state tree
  /// - Returns: array of actions in order. Pops are always first.
  static func getNavigationDiffActions(lastState: NavigationTreeNode<ViewController>?, currentState: NavigationTreeNode<ViewController>?) -> [NavigationTreeDiffAction<ViewController>] {
    
    var nodesToPop: [NavigationTreeNode<ViewController>] = []
    var nodesToPush: [NavigationTreeNode<ViewController>] = []
    
    //1. Find all the pops: nods that were in the last tree, but aren't in the current.
    //   The order of the nodes is in post-order.
    
    lastState?.traverse(postOrder: true) { node in
      if !containsNode(node, in: currentState) {
        nodesToPop.append(node)
      }
    }
    
    //2. Find all pushes: nodes that are in the current state, but weren't in the last one.
    //   The order of the nodes is in pre-order.
    currentState?.traverse(postOrder: false) { node in
      if !containsNode(node, in: lastState) {
        nodesToPush.append(node)
      }
    }
    
    // We need unique parents to go through them and find group all the pushes and pops
    // that happen on the same parent
    let uniquePushParents: [NavigationTreeNode<ViewController>?] = getUniqueParents(nodesToPush)
    var filteredSinglePopNodes = nodesToPop
    var insertActions: [NavigationTreeDiffAction<ViewController>] = []
    
    //3. Now we're merging all the complex pushes and pushes that have the corresponding pops
    //   We're doing it to create `change` actions.
    for uniquePushParent in uniquePushParents {
      let sameParentFilter: (NavigationTreeNode<ViewController>) -> Bool = {
        $0.parentNode == uniquePushParent
      }
      let differentParentFilter: (NavigationTreeNode<ViewController>) -> Bool = {
        $0.parentNode != uniquePushParent
      }
      
      let pushesWithSameParent = nodesToPush.filter(sameParentFilter)
      let popsWithSameParent = nodesToPop.filter(sameParentFilter)
      
      // If it's just a singular push, without a corresponding pop, it's a simple `push` action
      guard pushesWithSameParent.count > 1 || popsWithSameParent.count > 0 else {
        insertActions.append(.push(nodeToPush: pushesWithSameParent[0]))
        continue
      }
      
      // We're taking the children from the parent, to keep the original *order* of children
      let nodesToPush = uniquePushParent?.children ?? []
      // Otherwise, we're creating a `change` action with all the pushes and pops for the same parent
      insertActions.append(.changed(poppedNodes: popsWithSameParent, pushedNodes: nodesToPush))
      // We're removing the pops with the parent, because the difference has already been served in a `change` event
      filteredSinglePopNodes = filteredSinglePopNodes.filter(differentParentFilter)
    }
    
    
    return getPopActions(from: filteredSinglePopNodes) +
      insertActions +
      getChangedActiveChildActions(lastState: lastState, currentState: currentState)
  }
  
  /// - Parameter nodesToPop: an array of nodes to pop
  /// - Returns: singular pop actions and more complex pops (more than one)
  static func getPopActions(from nodesToPop: [NavigationTreeNode<ViewController>]) -> [NavigationTreeDiffAction<ViewController>] {
    var popActions: [NavigationTreeDiffAction<ViewController>] = []
    let uniquePopParents: [NavigationTreeNode<ViewController>?] = getUniqueParents(nodesToPop)
    
    for uniquePopParent in uniquePopParents {
      let popsWithSameParent = nodesToPop.filter {
        $0.parentNode == uniquePopParent
      }
      
      guard popsWithSameParent.count > 1 else {
        popActions.append(.pop(nodeToPop: popsWithSameParent[0]))
        continue
      }
      
      popActions.append(.changed(poppedNodes: popsWithSameParent, pushedNodes: []))
    }
    
    return popActions
  }
  
  /// `changedActiveChild` happens when a new child became active
  ///
  /// - Parameters:
  ///   - lastState: lastState tree
  ///   - currentState: currentState tree
  /// - Returns: `changedActiveChild` actions.
  static func getChangedActiveChildActions(lastState: NavigationTreeNode<ViewController>?, currentState: NavigationTreeNode<ViewController>?) -> [NavigationTreeDiffAction<ViewController>] {
    var changedActiveChildActions: [NavigationTreeDiffAction<ViewController>] = []
    currentState?.traverse(postOrder: true) { node in
      guard let currentActiveChild = node.getActiveChild() else {
        return
      }
      let lastStateNode = lastState?.find(value: node.value)
      let lastActiveChild = lastStateNode?.getActiveChild()
      
      if lastActiveChild != currentActiveChild {
        changedActiveChildActions.append(.changedActiveChild(child: currentActiveChild))
      } else {
        changedActiveChildActions.append(.selectedActiveChild(child: currentActiveChild))
      }
    }
    return changedActiveChildActions
  }
  
  static func getUniqueParents(_ nodes: [NavigationTreeNode<ViewController>]) -> [NavigationTreeNode<ViewController>?] {
    var uniqueParents: [NavigationTreeNode<ViewController>?] = []
    for node in nodes {
      let containsParent = uniqueParents.contains {
        $0 == node.parentNode
      }
      if !containsParent {
        uniqueParents.append(node.parentNode)
      }
    }
    return uniqueParents
  }
  
  static func containsNode(_ node: NavigationTreeNode<ViewController>, in tree: NavigationTreeNode<ViewController>?) -> Bool {
    return tree?.containsValue(value: node.value) ?? false
  }
}

//
//  NavigationMiddleware.swift
//  KatanaRouter
//
//  Created by John Whitley on 9/29/17.
//  Copyright © 2017 John Whitley. See LICENSE.md.
//

import ReactiveReSwift

public protocol RoutableState {
  associatedtype ViewController: AnyObject

  var navigationState: NavigationState<ViewController> { get set }
}

public class NavigationMiddleware<Store: RouterStore, ViewController: AnyObject, State: RoutableState>
  where State.ViewController == ViewController {

  var router: Router<Store, ViewController>!

  public init () { }

  public var middleware: Middleware<State> {
    return routerMiddleware
  }

  private var routerMiddleware: Middleware<State> {
    return Middleware<State>().sideEffect { getState, dispatch, action in
      switch action {
      case let setRootAction as SetRootDestination<ViewController>:
        if self.router == nil, let router = setRootAction.router as? Router<Store, ViewController> {
          self.router = router
        }

        self.router.setupRootForRoutable(state: getState(),  destination: setRootAction.root)

      case let addNewAction as AddNewDestinationCreator<ViewController, Store>:
        dispatch(AddNewDestination(destination: addNewAction.creator(self.router.store)))

      default:
        return
      }
    }
  }
}

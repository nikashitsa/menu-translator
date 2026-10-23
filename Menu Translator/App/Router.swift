import Observation
import SwiftUI
import UIKit

enum Route: Hashable {
    case scan
    case translation(UIImage?)
    case order(Order)
    case dishDetails(Dish)
}

@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route, animated: Bool = true) {
        withNavigationAnimation(animated) {
            path.append(route)
        }
    }

    func pop(animated: Bool = true) {
        withNavigationAnimation(animated) {
            _ = path.popLast()
        }
    }

    /// Returns to `route` if it is already in the stack, otherwise pushes it.
    func popToOrPush(_ route: Route) {
        if let index = path.lastIndex(of: route) {
            path.removeSubrange((index + 1)...)
        } else {
            path.append(route)
        }
    }

    func popToRoot() {
        path.removeAll()
    }
}

private func withNavigationAnimation(_ animated: Bool, _ body: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = !animated
    withTransaction(transaction, body)
}

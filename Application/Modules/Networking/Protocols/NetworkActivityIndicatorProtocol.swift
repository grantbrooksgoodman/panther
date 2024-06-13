//
//  NetworkActivityIndicatorProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol NetworkActivityIndicator {
    func show()
    func hide()
}

public struct DefaultNetworkActivityIndicator: NetworkActivityIndicator {
    public func show() {}
    public func hide() {}
}

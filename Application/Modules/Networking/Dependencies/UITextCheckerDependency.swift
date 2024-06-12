//
//  UITextCheckerDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import CoreArchitecture

public enum UITextCheckerDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> UITextChecker {
        .init()
    }
}

public extension DependencyValues {
    var uiTextChecker: UITextChecker {
        get { self[UITextCheckerDependency.self] }
        set { self[UITextCheckerDependency.self] = newValue }
    }
}

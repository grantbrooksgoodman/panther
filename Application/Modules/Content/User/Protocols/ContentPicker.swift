//
//  ContentPicker.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import CoreArchitecture

public protocol ContentPicker<Content> {
    associatedtype Content

    var onDismiss: (Exception?) -> Void { get }
    var onSelection: (Content) -> Void { get }
}

public extension ContentPicker {
    func dismiss(_ exception: Exception? = nil) {
        @Dependency(\.uiApplication.keyWindow?.rootViewController) var keyViewController: UIViewController?
        keyViewController?.dismiss(animated: true)
        onDismiss(exception)
    }
}

public extension Exception {
    static func contentPickerContentTypeMismatch(_ metadata: [Any]) -> Exception {
        .init("Failed to typecast result to specified content.", metadata: metadata)
    }
}

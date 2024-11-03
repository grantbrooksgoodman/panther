//
//  MenuElement.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public struct MenuElement {
    // MARK: - Types

    public struct Attributes: OptionSet {
        /* MARK: Properties */

        public static let `default`: Attributes = .init(rawValue: 1 << 0)
        public static let destructive: Attributes = .init(rawValue: 1 << 1)

        public let rawValue: Int8

        /* MARK: Computed Properties */

        var uiAttributes: UIAction.Attributes {
            var attributes = UIAction.Attributes()
            if contains(.destructive) {
                attributes.insert(.destructive)
            }
            return attributes
        }

        /* MARK: Init */

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }
    }

    // MARK: - Properties

    let attributes: Attributes
    let image: UIImage?
    let title: String

    var handler: ((MenuElement) -> Void)?

    // MARK: - Computed Properties

    var uiAction: UIAction {
        return .init(
            title: title,
            image: image,
            attributes: attributes.uiAttributes,
            handler: { _ in
                handler?(self)
            }
        )
    }

    // MARK: - Init

    public init(
        title: String,
        image: UIImage? = nil,
        attributes: Attributes = .default,
        handler: ((MenuElement) -> Void)? = nil
    ) {
        self.title = title
        self.image = image
        self.attributes = attributes
        self.handler = handler
    }
}

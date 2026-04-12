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

struct MenuElement: @unchecked Sendable {
    // MARK: - Types

    struct Attributes: OptionSet {
        /* MARK: Properties */

        static let `default`: Attributes = .init(rawValue: 1 << 0)
        static let destructive: Attributes = .init(rawValue: 1 << 1)

        let rawValue: Int8

        /* MARK: Computed Properties */

        var uiAttributes: UIAction.Attributes {
            var attributes = UIAction.Attributes()
            if contains(.destructive) {
                attributes.insert(.destructive)
            }
            return attributes
        }

        /* MARK: Init */

        init(rawValue: Int8) {
            self.rawValue = rawValue
        }
    }

    // MARK: - Properties

    let attributes: Attributes
    let identifier: UIAction.Identifier?
    let image: UIImage?
    let title: String

    var handler: ((MenuElement) -> Void)?

    // MARK: - Computed Properties

    @MainActor
    var uiAction: UIAction {
        .init(
            title: title,
            image: image,
            identifier: identifier,
            attributes: attributes.uiAttributes,
            handler: { _ in
                handler?(self)
            }
        )
    }

    // MARK: - Init

    init(
        title: String,
        image: UIImage? = nil,
        identifier: UIAction.Identifier? = nil,
        attributes: Attributes = .default,
        handler: ((MenuElement) -> Void)? = nil
    ) {
        self.title = title
        self.image = image
        self.identifier = identifier
        self.attributes = attributes
        self.handler = handler
    }
}

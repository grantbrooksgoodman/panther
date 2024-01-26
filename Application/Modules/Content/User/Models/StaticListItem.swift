//
//  StaticListItem.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public struct StaticListItem: Equatable, Hashable {
    // MARK: - Properties

    public let action: (() -> Void)?
    public let destination: (() -> any View)?
    public let imageData: (image: Image, color: Color)?
    public let title: String

    private let id = UUID()

    // MARK: - Init

    public init(
        title: String,
        imageData: (image: Image, color: Color)? = nil,
        action: (() -> Void)? = nil,
        destination: (() -> any View)? = nil
    ) {
        assert(!(action != nil && destination != nil), "Initialized StaticListItem with both action and destination specified")
        self.title = title
        self.imageData = imageData
        self.action = action
        self.destination = destination
    }

    // MARK: - Equatable Conformance

    public static func == (left: StaticListItem, right: StaticListItem) -> Bool {
        let sameID = left.id == right.id
        let sameImageDateColor = left.imageData?.color == right.imageData?.color
        let sameTitle = left.title == right.title

        guard sameID,
              sameImageDateColor,
              sameTitle else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(imageData?.color)
        hasher.combine(title)
    }
}

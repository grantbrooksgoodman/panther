//
//  ConversationSyncData.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ConversationSyncData: Hashable {
    // MARK: - Properties

    public let conversation: Conversation
    public let newData: [String: Any]

    // MARK: - Computed Properties

    public static let empty: ConversationSyncData = .init(.empty, newData: [:])

    // MARK: - Init

    public init(
        _ conversation: Conversation,
        newData: [String: Any]
    ) {
        self.conversation = conversation
        self.newData = newData
    }

    // MARK: - Equatable Conformance

    public static func == (left: ConversationSyncData, right: ConversationSyncData) -> Bool {
        let leftObjectCount = left.newData.count + left.newData.compactMapValues { $0 as? [String: Any] }.count
        let rightObjectCount = right.newData.count + right.newData.compactMapValues { $0 as? [String: Any] }.count

        guard left.conversation == right.conversation,
              leftObjectCount == rightObjectCount else { return false }

        return true
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(conversation)
        hasher.combine(newData.count + newData.compactMapValues { $0 as? [String: Any] }.count)
    }
}

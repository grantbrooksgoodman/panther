//
//  ReadReceipt+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension ReadReceipt: Serializable {
    // MARK: - Properties

    /// The serialized representation of the read receipt.
    var encoded: String {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return "\(userID) | \(dateFormatter.string(from: readDate))"
    }

    // MARK: - Init

    /// Creates a read receipt by decoding the given serialized string.
    ///
    /// Decoded read receipts are cached in memory.
    ///
    /// - Parameter data: The serialized read receipt string.
    ///
    /// - Throws: An `Exception` if the string cannot be decoded.
    init(
        from data: String
    ) async throws(Exception) {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        if let cachedValue = _ReadReceiptCache.cachedReadReceiptsForEncodedStrings?[data] {
            self = cachedValue
            return
        }

        let components = data.components(separatedBy: " | ")
        guard components.count == 2,
              !components[0].isBangQualifiedEmpty,
              let readDate = dateFormatter.date(from: components[1]) else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        let decoded: ReadReceipt = .init(
            userID: components[0],
            readDate: readDate
        )

        var cachedReadReceiptsForEncodedStrings = _ReadReceiptCache.cachedReadReceiptsForEncodedStrings ?? [:]
        cachedReadReceiptsForEncodedStrings[data] = decoded
        _ReadReceiptCache.cachedReadReceiptsForEncodedStrings = cachedReadReceiptsForEncodedStrings

        self = decoded
    }

    // MARK: - Methods

    /// Returns a Boolean value that indicates whether a read receipt can be decoded from the given
    /// string.
    ///
    /// - Parameter data: The serialized read receipt string.
    ///
    /// - Returns: `true` if a read receipt can be decoded; otherwise, `false`.
    static func canDecode(from data: String) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        let components = data.components(separatedBy: " | ")
        guard components.count == 2,
              !components[0].isBangQualifiedEmpty,
              dateFormatter.date(from: components[1]) != nil else { return false }

        return true
    }
}

/// A namespace for managing the in-memory read receipt cache.
enum ReadReceiptCache {
    /// Removes every cached read receipt.
    static func clearCache() {
        _ReadReceiptCache.clearCache()
    }
}

private enum _ReadReceiptCache {
    // MARK: - Properties

    private static let _cachedReadReceiptsForEncodedStrings = LockIsolated<[String: ReadReceipt]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedReadReceiptsForEncodedStrings: [String: ReadReceipt]? {
        get { _cachedReadReceiptsForEncodedStrings.wrappedValue }
        set { _cachedReadReceiptsForEncodedStrings.wrappedValue = newValue }
    }

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedReadReceiptsForEncodedStrings = nil
    }
}

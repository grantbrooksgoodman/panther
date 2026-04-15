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
    // MARK: - Type Aliases

    typealias T = ReadReceipt

    // MARK: - Properties

    var encoded: String {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return "\(userID) | \(dateFormatter.string(from: readDate))"
    }

    // MARK: - Methods

    static func canDecode(from data: String) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        let components = data.components(separatedBy: " | ")
        guard components.count == 2,
              !components[0].isBangQualifiedEmpty,
              dateFormatter.date(from: components[1]) != nil else { return false }

        return true
    }

    static func decode(from data: String) async -> Callback<ReadReceipt, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        if let cachedValue = _ReadReceiptCache.cachedReadReceiptsForEncodedStrings?[data] {
            return .success(cachedValue)
        }

        let components = data.components(separatedBy: " | ")
        guard components.count == 2,
              !components[0].isBangQualifiedEmpty,
              let readDate = dateFormatter.date(from: components[1]) else {
            return .failure(.Networking.decodingFailed(data: data, .init(sender: self)))
        }

        let decoded: ReadReceipt = .init(
            userID: components[0],
            readDate: readDate
        )

        var cachedReadReceiptsForEncodedStrings = _ReadReceiptCache.cachedReadReceiptsForEncodedStrings ?? [:]
        cachedReadReceiptsForEncodedStrings[data] = decoded
        _ReadReceiptCache.cachedReadReceiptsForEncodedStrings = cachedReadReceiptsForEncodedStrings

        return .success(decoded)
    }
}

enum ReadReceiptCache {
    static func clearCache() {
        _ReadReceiptCache.clearCache()
    }
}

private enum _ReadReceiptCache {
    // MARK: - Properties

    private static let _cachedReadReceiptsForEncodedStrings = LockIsolated<[String: ReadReceipt]?>(wrappedValue: nil)

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

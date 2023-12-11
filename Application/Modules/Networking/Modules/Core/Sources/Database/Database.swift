//
//  Database.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct Database {
    // MARK: - Dependencies

    @Dependency(\.coreDatabase) private var coreDatabase: CoreDatabase

    // MARK: - ID Key Generation

    public func generateKey(for path: String) -> String? {
        coreDatabase.generateKey(for: path)
    }

    // MARK: - Value Retrieval

    public func getValues(
        at path: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration? = nil
    ) async -> Callback<Any, Exception> {
        return await withCheckedContinuation { continuation in
            coreDatabase.getValues(
                at: path,
                prependingEnvironment: prependingEnvironment,
                timeout: duration ?? .seconds(10)
            ) { getValuesResult in
                continuation.resume(returning: getValuesResult)
            }
        }
    }

    public func queryValues(
        at path: String,
        strategy: CoreDatabase.QueryStrategy = .first(10),
        prependingEnvironment: Bool = true,
        timeout duration: Duration? = nil
    ) async -> Callback<Any, Exception> {
        return await withCheckedContinuation { continuation in
            coreDatabase.queryValues(
                at: path,
                strategy: strategy,
                prependingEnvironment: prependingEnvironment,
                timeout: duration ?? .seconds(10)
            ) { queryValuesResult in
                continuation.resume(returning: queryValuesResult)
            }
        }
    }

    // MARK: - Value Setting

    @discardableResult
    public func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool = true,
        timeout duration: Duration? = nil
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreDatabase.setValue(
                value,
                forKey: key,
                prependingEnvironment: prependingEnvironment,
                timeout: duration ?? .seconds(10)
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    @discardableResult
    public func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool = true,
        timeout duration: Duration? = nil
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreDatabase.updateChildValues(
                forKey: key,
                with: data,
                prependingEnvironment: prependingEnvironment,
                timeout: duration ?? .seconds(10)
            ) { exception in
                continuation.resume(returning: exception)
            }
        }
    }
}

/* MARK: CoreDatabase Dependency */

private enum CoreDatabaseDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CoreDatabase {
        .init()
    }
}

private extension DependencyValues {
    var coreDatabase: CoreDatabase {
        get { self[CoreDatabaseDependency.self] }
        set { self[CoreDatabaseDependency.self] = newValue }
    }
}

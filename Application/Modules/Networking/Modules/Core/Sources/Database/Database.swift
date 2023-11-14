//
//  Database.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 23/10/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct Database {
    // MARK: - Dependencies

    @Dependency(\.coreDatabase) private var coreDatabase: CoreDatabase

    // MARK: - Value Retrieval

    public func getValues(
        at path: String,
        timeout duration: Duration? = nil
    ) async -> Callback<Any, Exception> {
        return await withCheckedContinuation { continuation in
            coreDatabase.getValues(
                at: path,
                timeout: duration ?? .seconds(10)
            ) { values, exception in
                guard let values else {
                    let exception = exception ?? .init(metadata: [self, #file, #function, #line])
                    continuation.resume(returning: .failure(exception))
                    return
                }

                continuation.resume(returning: .success(values))
            }
        }
    }

    public func queryValues(
        at path: String,
        limit: Int,
        strategy: CoreDatabase.QueryStrategy = .first,
        timeout duration: Duration? = nil
    ) async -> Callback<Any, Exception> {
        return await withCheckedContinuation { continuation in
            coreDatabase.getValues(
                at: path,
                timeout: duration ?? .seconds(10)
            ) { values, exception in
                guard let values else {
                    let exception = exception ?? .init(metadata: [self, #file, #function, #line])
                    continuation.resume(returning: .failure(exception))
                    return
                }

                continuation.resume(returning: .success(values))
            }
        }
    }

    // MARK: - Value Setting

    @discardableResult
    public func setValue(
        _ value: Any,
        forKey key: String,
        timeout duration: Duration? = nil
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreDatabase.setValue(
                value,
                forKey: key,
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
        timeout duration: Duration? = nil
    ) async -> Exception? {
        return await withCheckedContinuation { continuation in
            coreDatabase.updateChildValues(
                forKey: key,
                with: data,
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

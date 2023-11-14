//
//  CoreDatabase.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseDatabase
import Redux

public struct CoreDatabase {
    // MARK: - Types

    public enum QueryStrategy {
        case first
        case last
    }

    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference

    // MARK: - Value Retrieval

    /**
     Gets values on the server for a given path.

     - Parameter atPath: The server path at which to retrieve values.
     - Parameter timeout: An optional timeout `Duration` for the operation; defaults to 10 seconds.
     - Parameter completion: Returns the Firebase snapshot value.
     */
    public func getValues(
        at path: String,
        timeout duration: Duration = .seconds(10),
        completion: @escaping (
            _ values: Any?,
            _ exception: Exception?
        ) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(nil, .timedOut([self, #file, #function, #line]))
        }

        firebaseDatabase.child(path.prepended).observeSingleEvent(of: .value) { snapshot in
            timeout.cancel()
            guard canComplete else { return }
            completion(snapshot.value, nil)
        } withCancel: { error in
            timeout.cancel()
            guard canComplete else { return }
            completion(nil, .init(error, metadata: [self, #file, #function, #line]))
        }
    }

    public func queryValues(
        at path: String,
        limit: Int,
        strategy: QueryStrategy = .first,
        timeout duration: Duration = .seconds(10),
        completion: @escaping (
            _ values: Any?,
            _ exception: Exception?
        ) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(nil, .timedOut([self, #file, #function, #line]))
        }

        func processReturnValues(_ error: Error?, _ snapshot: DataSnapshot?) {
            timeout.cancel()
            guard canComplete else { return }

            guard let snapshot,
                  let value = snapshot.value else {
                completion(nil, .init(error, metadata: [self, #file, #function, #line]))
                return
            }

            completion(value, nil)
        }

        let reference = firebaseDatabase.child(path.prepended)

        switch strategy {
        case .first:
            reference.queryLimited(toFirst: .init(limit)).getData { error, snapshot in
                processReturnValues(error, snapshot)
            }

        case .last:
            reference.queryLimited(toLast: .init(limit)).getData { error, snapshot in
                processReturnValues(error, snapshot)
            }
        }
    }

    // MARK: - Value Setting

    public func setValue(
        _ value: Any,
        forKey key: String,
        timeout duration: Duration = .seconds(10),
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        firebaseDatabase.child(key.prepended).setValue(value) { error, _ in
            timeout.cancel()
            guard canComplete else { return }
            completion(error == nil ? nil : .init(error, metadata: [self, #file, #function, #line]))
        }
    }

    public func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        timeout duration: Duration = .seconds(10),
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        firebaseDatabase.child(key).updateChildValues(data) { error, _ in
            timeout.cancel()
            guard canComplete else { return }
            completion(error == nil ? nil : .init(error, metadata: [self, #file, #function, #line]))
        }
    }
}

private extension String {
    var prepended: String {
        prependingCurrentEnvironment
    }
}

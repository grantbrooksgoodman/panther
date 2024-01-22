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
        case first(Int)
        case last(Int)
    }

    // MARK: - Dependencies

    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.networking.activityIndicator) private var networkActivity: NetworkActivityIndicator

    // MARK: - ID Key Generation

    public func generateKey(for path: String) -> String? {
        // swiftformat:disable acronyms
        firebaseDatabase.child(path).childByAutoId().key
        // swiftformat:enable acronyms
    }

    // MARK: - Data Integrity Validation

    public func isEncodable(_ value: Any) -> Bool {
        let array = value as? [Any]
        let nsArray = value as? NSArray

        let dictionary = value as? [AnyHashable: Any]
        let nsDictionary = value as? NSDictionary

        let null = value as? NSNull

        let number = value as? Float
        let nsNumber = value as? NSNumber

        let string = value as? String
        let nsString = value as? NSString

        let compiled: [Any?] = [
            array,
            nsArray,
            dictionary,
            nsDictionary,
            null,
            number,
            nsNumber,
            string,
            nsString,
        ]

        if let array {
            guard array.allSatisfy({ isEncodable($0) }) else { return false }
        }

        if let nsArray {
            guard nsArray.allSatisfy({ isEncodable($0) }) else { return false }
        }

        if let dictionary {
            guard dictionary.values.allSatisfy({ isEncodable($0) }) else { return false }
        }

        if let nsDictionary {
            guard nsDictionary.allValues.allSatisfy({ isEncodable($0) }) else { return false }
        }

        return !compiled.allSatisfy { $0 == nil }
    }

    // MARK: - Value Retrieval

    /**
     Gets values on the server for a given path.

     - Parameter paht: The server path at which to retrieve values.
     - Parameter timeout: An optional timeout `Duration` for the operation; defaults to 10 seconds.
     - Parameter completion: Returns the Firebase snapshot value.
     */
    public func getValues(
        at path: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Any, Exception>) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(.timedOut([self, #file, #function, #line])))
        }

        Logger.log(
            "Getting values at path \"\(path)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let path = prependingEnvironment ? path.prepended : path
        firebaseDatabase.child(path).observeSingleEvent(of: .value) { snapshot in
            timeout.cancel()
            guard canComplete else { return }

            guard !isEmpty(snapshot.value),
                  let value = snapshot.value else {
                completion(.failure(.init(
                    "No value exists at the specified key path.",
                    extraParams: ["Path": path],
                    metadata: [self, #file, #function, #line]
                )))
                return
            }

            completion(.success(value))
        } withCancel: { error in
            timeout.cancel()
            guard canComplete else { return }
            completion(.failure(.init(error, metadata: [self, #file, #function, #line])))
        }
    }

    public func queryValues(
        at path: String,
        strategy: QueryStrategy = .first(10),
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ callback: Callback<Any, Exception>) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.failure(.timedOut([self, #file, #function, #line])))
        }

        Logger.log(
            "Querying values at path \"\(path)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let path = prependingEnvironment ? path.prepended : path

        func processReturnValues(_ error: Error?, _ snapshot: DataSnapshot?) {
            timeout.cancel()
            guard canComplete else { return }

            guard let snapshot else {
                completion(.failure(.init(error, metadata: [self, #file, #function, #line])))
                return
            }

            guard !isEmpty(snapshot.value),
                  let value = snapshot.value else {
                completion(.failure(.init(
                    "No value exists at the specified key path.",
                    extraParams: ["Path": path],
                    metadata: [self, #file, #function, #line]
                )))
                return
            }

            completion(.success(value))
        }

        let reference = firebaseDatabase.child(path)

        switch strategy {
        case let .first(limit):
            reference.queryLimited(toFirst: .init(limit)).getData { error, snapshot in
                processReturnValues(error, snapshot)
            }

        case let .last(limit):
            reference.queryLimited(toLast: .init(limit)).getData { error, snapshot in
                processReturnValues(error, snapshot)
            }
        }
    }

    // MARK: - Value Setting

    public func setValue(
        _ value: Any,
        forKey key: String,
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        guard isEncodable(value) else {
            guard canComplete else { return }
            completion(.invalidType(value: value, [self, #file, #function, #line]))
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Setting value \"\(value)\" for key \"\(key)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let key = prependingEnvironment ? key.prepended : key
        firebaseDatabase.child(key).setValue(value) { error, _ in
            timeout.cancel()
            guard canComplete else { return }
            completion(error == nil ? nil : .init(error, metadata: [self, #file, #function, #line]))
        }
    }

    public func updateChildValues(
        forKey key: String,
        with data: [String: Any],
        prependingEnvironment: Bool,
        timeout duration: Duration,
        completion: @escaping (_ exception: Exception?) -> Void
    ) {
        networkActivity.show()

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            networkActivity.hide()
            return true
        }

        guard data.values.allSatisfy({ isEncodable($0) }) else {
            guard canComplete else { return }
            completion(.invalidType(value: data, [self, #file, #function, #line]))
            return
        }

        let timeout = Timeout(after: duration) {
            guard canComplete else { return }
            completion(.timedOut([self, #file, #function, #line]))
        }

        Logger.log(
            "Updating child values for key \"\(key)\" with \"\(data)\".",
            domain: .database,
            metadata: [self, #file, #function, #line]
        )

        let key = prependingEnvironment ? key.prepended : key
        firebaseDatabase.child(key).updateChildValues(data) { error, _ in
            timeout.cancel()
            guard canComplete else { return }
            completion(error == nil ? nil : .init(error, metadata: [self, #file, #function, #line]))
        }
    }

    // MARK: - Auxiliary

    private func isEmpty(_ value: Any?) -> Bool { value as? NSNull != nil }
}

private extension String {
    var prepended: String {
        prependingCurrentEnvironment
    }
}

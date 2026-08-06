//
//  RollbackService.swift
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

// TODO: Absorb this concept into Networking, more fleshed out.
struct RollbackService {
    // MARK: - Dependencies

    @Dependency(\.networking.integrityService) private var integrityService: IntegrityService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.timestampDateFormatter) private var timestampDateFormatter: DateFormatter

    // MARK: - Properties

    fileprivate static let shared = RollbackService()

    // MARK: - Init

    private init() {}

    // MARK: - Capture Snapshot

    func captureSnapshot(
        of environment: NetworkEnvironment = Networking.config.environment
    ) async throws(Exception) {
        let snapshots = try await listSnapshots(of: environment)
        guard let latestKey = Array(snapshots.keys).sorted().last,
              let snapshotFileName = snapshots[latestKey] else {
            throw Exception(
                "Failed to resolve latest snapshot.",
                metadata: .init(sender: self)
            )
        }

        let latestSnapshotData: Data?
        do {
            latestSnapshotData = try await JSONSerialization.data(
                withJSONObject: retrieveSnapshot(
                    fileName: snapshotFileName,
                    environment: environment
                ),
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                ]
            )
        } catch let exception as Exception {
            Logger.log(exception)
            latestSnapshotData = nil
        } catch {
            Logger.log(.init(
                error,
                metadata: .init(sender: self)
            ))

            latestSnapshotData = nil
        }

        let preparedData = try await prepareJSONData(for: environment)
        let fileName = "\(timestampDateFormatter.string(from: Date.now)).json"

        guard preparedData.count != latestSnapshotData?.count else {
            return Logger.log(
                "Skipping capture – data is equal to latest snapshot.",
                domain: .rollbackService,
                sender: self
            )
        }

        try await networking.storage.upload(
            preparedData,
            metadata: .init(
                "\(environment.shortString)/snapshots/\(fileName)",
                contentType: "application/json"
            ),
            prependingEnvironment: false,
            timeout: .seconds(300)
        )

        Logger.log(
            "Captured snapshot of \(environment.description) environment.",
            domain: .rollbackService,
            sender: self
        )
    }

    // MARK: - Roll Back to Latest Snapshot

    func rollbackToLatestSnapshot(
        in environment: NetworkEnvironment
    ) async throws(Exception) {
        func rollback(
            _ environment: NetworkEnvironment,
            toSnapshotWith fileName: String
        ) async throws(Exception) {
            try await networking.database.setValue(
                retrieveSnapshot(
                    fileName: fileName,
                    environment: environment
                ),
                forKey: environment.shortString,
                prependingEnvironment: false,
                timeout: .seconds(300)
            )
        }

        let snapshots = try await listSnapshots(of: environment)
        guard let latestKey = Array(snapshots.keys).sorted().last,
              let snapshotFileName = snapshots[latestKey] else {
            throw Exception(
                "Failed to resolve latest snapshot.",
                metadata: .init(sender: self)
            )
        }

        try await rollback(
            environment,
            toSnapshotWith: snapshotFileName
        )

        Logger.log(
            "Rolled back \(environment.description) environment to latest snapshot.",
            domain: .rollbackService,
            sender: self
        )
    }

    // MARK: - Auxiliary

    private func listSnapshots(
        of environment: NetworkEnvironment
    ) async throws(Exception) -> [Date: String] {
        try await networking.storage.getDirectoryListing(
            at: "\(environment.shortString)/snapshots",
            prependingEnvironment: false
        )
        .filePaths
        .reduce(
            into: [Date: String]()
        ) { partialResult, filePath in
            let fileName = filePath.lastPathComponent
            if let date = timestampDateFormatter.date(
                from: fileName
            ) {
                partialResult[date] = "\(fileName).json"
            }
        }
    }

    private func prepareJSONData(
        for environment: NetworkEnvironment
    ) async throws(Exception) -> Data {
        let snapshot: [String: Any] = try await networking.database.getValues(
            at: environment.shortString,
            prependingEnvironment: false,
            timeout: .seconds(300)
        )

        guard JSONSerialization.isValidJSONObject(snapshot) else {
            throw Exception(
                "Invalid JSON object.",
                userInfo: ["Data": snapshot],
                metadata: .init(sender: self)
            )
        }

        do {
            return try JSONSerialization.data(
                withJSONObject: snapshot,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                ]
            )
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func retrieveSnapshot(
        fileName: String,
        environment: NetworkEnvironment
    ) async throws(Exception) -> [String: Any] {
        let localURLPath = URL.temporaryDirectory.appending(path: fileName)
        try await networking.storage.downloadItem(
            at: "\(environment.shortString)/snapshots/\(fileName)",
            to: localURLPath,
            prependingEnvironment: false,
            timeout: .seconds(300)
        )

        let data = try Data.fromURL(localURLPath)
        let snapshot: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any] else {
                throw Exception.Networking.decodingFailed(
                    data: data,
                    .init(sender: self)
                )
            }

            snapshot = decoded
        } catch let exception as Exception {
            throw exception
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        return snapshot
    }
}

enum RollbackServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> RollbackService {
        .shared
    }
}

extension DependencyValues {
    var rollbackService: RollbackService {
        get { self[RollbackServiceDependency.self] }
        set { self[RollbackServiceDependency.self] = newValue }
    }
}

extension LoggerDomain {
    static let rollbackService = LoggerDomain("rollbackService")
}

private extension String {
    // TODO: Audit the "?? self".
    var lastPathComponent: String {
        components(separatedBy: "/")
            .last?
            .components(separatedBy: ".")
            .first ?? self
    }
}

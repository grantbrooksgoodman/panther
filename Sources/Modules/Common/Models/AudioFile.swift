//
//  AudioFile.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Foundation

/* Proprietary */
import AppSubsystem

final class AudioFile: Codable, Equatable, Sendable {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.AudioFile

    // MARK: - Types

    private enum CodingKeys: String, CodingKey {
        case contentDuration
        case fileExtension
        case name
        case url
    }

    // MARK: - Properties

    let fileExtension: AudioFileExtension
    let name: String
    let url: URL

    private let _contentDuration = LockIsolated<Float?>(wrappedValue: nil)

    // MARK: - Computed Properties

    var contentDuration: Float? {
        get { _contentDuration.wrappedValue }
        set { _contentDuration.wrappedValue = newValue; didSetDuration() }
    }

    // MARK: - Init

    init(
        _ url: URL,
        name: String,
        fileExtension: AudioFileExtension,
        contentDuration: Float
    ) {
        self.url = url
        self.name = name
        self.fileExtension = fileExtension
        self.contentDuration = contentDuration
    }

    convenience init?(_ url: URL) {
        @Dependency(\.fileManager) var fileManager: FileManager

        guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)),
              let fileName = url.absoluteString.components(separatedBy: "/").last,
              fileName.components(separatedBy: ".").count == 2 else { return nil }

        let components = fileName.components(separatedBy: ".")
        guard components[1] == MediaFileExtension.audio(.caf).rawValue ||
            components[1] == MediaFileExtension.audio(.m4a).rawValue else { return nil }

        self.init(
            url,
            name: components[0],
            fileExtension: components[1] == MediaFileExtension.audio(.caf).rawValue ? .caf : .m4a,
            contentDuration: 0
        )

        if let cachedValue = _AudioFileDurationCache.cachedDurationsForLocalPaths?[url] {
            contentDuration = cachedValue
            return
        }

        Task {
            if let exception = await setDuration() {
                Logger.log(exception)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fileExtension = try container.decode(AudioFileExtension.self, forKey: .fileExtension)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)

        _contentDuration.wrappedValue = try container.decode(
            Float.self,
            forKey: .contentDuration
        )
    }

    // MARK: - Codable Conformance

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentDuration ?? 0, forKey: .contentDuration)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
    }

    // MARK: - Equatable Conformance

    static func == (left: AudioFile, right: AudioFile) -> Bool {
        let sameContentDuration = left.contentDuration == right.contentDuration
        let sameFileExtension = left.fileExtension == right.fileExtension
        let sameName = left.name == right.name
        let sameURL = left.url == right.url

        guard sameContentDuration,
              sameFileExtension,
              sameName,
              sameURL else { return false }

        return true
    }

    // MARK: - Auxiliary

    private func didSetDuration() {
        @Dependency(\.notificationCenter) var notificationCenter: NotificationCenter
        notificationCenter.post(
            name: .init(rawValue: Strings.setDurationNotificationName),
            object: self,
            userInfo: [
                Strings.durationNotificationUserInfoKey: contentDuration ?? 0,
                Strings.urlNotificationUserInfoKey: url,
            ]
        )
    }

    private func setDuration() async -> Exception? {
        do {
            let assetReader = try AVAssetReader(asset: .init(url: url))
            let duration: Float = await try .init(assetReader.asset.load(.duration).seconds)
            guard duration > 0 else { return nil }

            var cachedDurationsForLocalPaths = _AudioFileDurationCache.cachedDurationsForLocalPaths ?? [:]
            cachedDurationsForLocalPaths[url] = duration
            _AudioFileDurationCache.cachedDurationsForLocalPaths = cachedDurationsForLocalPaths

            contentDuration = duration
        } catch {
            return .init(error, metadata: .init(sender: self))
        }

        return nil
    }
}

enum AudioFileDurationCache {
    static func clearCache() {
        _AudioFileDurationCache.clearCache()
    }
}

private enum _AudioFileDurationCache {
    // MARK: - Properties

    fileprivate static var cachedDurationsForLocalPaths: [URL: Float]? {
        get { _cachedDurationsForLocalPaths.wrappedValue }
        set { _cachedDurationsForLocalPaths.wrappedValue = newValue }
    }

    private static let _cachedDurationsForLocalPaths = LockIsolated<[URL: Float]?>(wrappedValue: nil)

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedDurationsForLocalPaths = nil
    }
}

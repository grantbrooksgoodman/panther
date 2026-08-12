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

/// An audio file on disk and its content duration.
///
/// Use ``AudioFile`` to represent audio content such as voice messages. Creating a file from a
/// URL loads its duration asynchronously when it is not already cached, and the file posts a
/// notification whenever the duration is set. Durations are cached in memory by URL; use
/// ``AudioFileDurationCache/clearCache()`` to release them.
///
/// - Note: Unlike ``MediaFile``, an audio file locates its content by absolute URL.
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

    /// The file's extension.
    let fileExtension: AudioFileExtension

    /// The file's name, without an extension.
    let name: String

    /// The absolute URL of the file.
    let url: URL

    private let _contentDuration = LockIsolated<Float?>(nil)

    // MARK: - Computed Properties

    /// The duration of the audio content in seconds, or `nil` if it has not been determined.
    ///
    /// Setting this value posts a notification carrying the new duration and the file's URL.
    var contentDuration: Float? {
        get { _contentDuration.wrappedValue }
        set { _contentDuration.wrappedValue = newValue; didSetDuration() }
    }

    // MARK: - Init

    /// Creates an audio file with the given URL, name, extension, and duration.
    ///
    /// - Parameters:
    ///   - url: The absolute URL of the file.
    ///   - name: The file's name, without an extension.
    ///   - fileExtension: The file's extension.
    ///   - contentDuration: The duration of the audio content in seconds.
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

    /// Creates an audio file from the given URL, deriving its name and extension.
    ///
    /// If the duration for the URL is cached, the initializer applies it; otherwise, the
    /// duration loads asynchronously, and the file posts a notification when it becomes
    /// available.
    ///
    /// - Parameter url: The absolute URL of the file. The URL's final component must consist of
    ///   a name and a supported audio extension.
    ///
    /// - Returns: An audio file, or `nil` if no file exists at the URL or its name and extension
    ///   cannot be derived.
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
            do throws(Exception) {
                try await setDuration()
            } catch {
                Logger.log(error)
            }
        }
    }

    /// Creates an audio file by decoding from the given decoder.
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

    /// Encodes this audio file into the given encoder.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentDuration ?? 0, forKey: .contentDuration)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
    }

    // MARK: - Equatable Conformance

    /// Returns a Boolean value that indicates whether two audio files are equal, comparing their
    /// durations, extensions, names, and URLs.
    static func == (
        left: AudioFile,
        right: AudioFile
    ) -> Bool {
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

    private func setDuration() async throws(Exception) {
        do {
            let assetReader = try AVAssetReader(asset: AVURLAsset(url: url))
            let duration: Float = try await .init(assetReader.asset.load(.duration).seconds)
            guard duration > 0 else { return }

            var cachedDurationsForLocalPaths = _AudioFileDurationCache.cachedDurationsForLocalPaths ?? [:]
            cachedDurationsForLocalPaths[url] = duration
            _AudioFileDurationCache.cachedDurationsForLocalPaths = cachedDurationsForLocalPaths

            contentDuration = duration
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }
}

/// A namespace for managing the in-memory audio duration cache.
enum AudioFileDurationCache {
    /// Removes every cached audio duration.
    static func clearCache() {
        _AudioFileDurationCache.clearCache()
    }
}

private enum _AudioFileDurationCache {
    // MARK: - Properties

    private static let _cachedDurationsForLocalPaths = LockIsolated<[URL: Float]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedDurationsForLocalPaths: [URL: Float]? {
        get { _cachedDurationsForLocalPaths.wrappedValue }
        set { _cachedDurationsForLocalPaths.wrappedValue = newValue }
    }

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedDurationsForLocalPaths = nil
    }
}

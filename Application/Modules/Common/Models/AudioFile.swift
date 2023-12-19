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

/* 3rd-party */
import Redux

public final class AudioFile: Codable, Equatable {
    // MARK: - Properties

    public let fileExtension: AudioFileExtension
    public let name: String
    public let url: URL

    public private(set) var duration: Float?

    // MARK: - Init

    public init(
        _ url: URL,
        name: String,
        fileExtension: AudioFileExtension,
        duration: Float
    ) {
        self.url = url
        self.name = name
        self.fileExtension = fileExtension
        self.duration = duration
    }

    public convenience init?(_ url: URL) {
        @Dependency(\.fileManager) var fileManager: FileManager

        guard let decodedPath = url.path().removingPercentEncoding,
              fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: decodedPath),
              let fileName = url.absoluteString.components(separatedBy: "/").last,
              fileName.components(separatedBy: ".").count == 2 else { return nil }

        let components = fileName.components(separatedBy: ".")
        guard components[1] == AudioFileExtension.caf.rawValue ||
            components[1] == AudioFileExtension.m4a.rawValue else { return nil }
        self.init(
            url,
            name: components[0],
            fileExtension: components[1] == AudioFileExtension.caf.rawValue ? .caf : .m4a,
            duration: 0
        )

        Task {
            if let exception = await setDuration() {
                Logger.log(exception)
            }
        }
    }

    // MARK: - Equatable Conformance

    public static func == (left: AudioFile, right: AudioFile) -> Bool {
        let sameDuration = left.duration == right.duration
        let sameFileExtension = left.fileExtension == right.fileExtension
        let sameName = left.name == right.name
        let sameURL = left.url == right.url

        guard sameDuration,
              sameFileExtension,
              sameName,
              sameURL else { return false }

        return true
    }

    // MARK: - Auxiliary

    private func setDuration() async -> Exception? {
        do {
            let assetReader = try AVAssetReader(asset: .init(url: url))
            let duration: Float = try .init(await assetReader.asset.load(.duration).seconds)
            self.duration = duration
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }
}

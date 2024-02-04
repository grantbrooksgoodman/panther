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

    public private(set) var contentDuration: Float?

    // MARK: - Init

    public init(
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

    public convenience init?(_ url: URL) {
        @Dependency(\.fileManager) var fileManager: FileManager

        guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)),
              let fileName = url.absoluteString.components(separatedBy: "/").last,
              fileName.components(separatedBy: ".").count == 2 else { return nil }

        let components = fileName.components(separatedBy: ".")
        guard components[1] == AudioFileExtension.caf.rawValue ||
            components[1] == AudioFileExtension.m4a.rawValue else { return nil }

        self.init(
            url,
            name: components[0],
            fileExtension: components[1] == AudioFileExtension.caf.rawValue ? .caf : .m4a,
            contentDuration: 0
        )

        Task {
            if let exception = await setDuration() {
                Logger.log(exception)
            }
        }
    }

    // MARK: - Equatable Conformance

    public static func == (left: AudioFile, right: AudioFile) -> Bool {
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

    private func setDuration() async -> Exception? {
        do {
            let assetReader = try AVAssetReader(asset: .init(url: url))
            let duration: Float = try .init(await assetReader.asset.load(.duration).seconds)
            contentDuration = duration
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }
}

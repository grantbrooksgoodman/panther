//
//  ImageFile.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

// public final class ImageFile: Codable, Equatable {
//    // MARK: - Properties
//
//    public let fileExtension: ImageFileExtension
//    public let name: String
//    public let urlPath: URL
//
//    // MARK: - Init
//
//    public init(
//        _ urlPath: URL,
//        name: String,
//        fileExtension: ImageFileExtension
//    ) {
//        self.urlPath = urlPath
//        self.name = name
//        self.fileExtension = fileExtension
//    }
//
//    public convenience init?(_ url: URL) {
//        @Dependency(\.fileManager) var fileManager: FileManager
//
//        guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)),
//              let fileName = url.absoluteString.components(separatedBy: "/").last,
//              fileName.components(separatedBy: ".").count == 2 else { return nil }
//
//        let components = fileName.components(separatedBy: ".")
//        guard components[1] == ImageFileExtension.png.rawValue else { return nil }
//
//        self.init(
//            url,
//            name: components[0],
//            fileExtension: .png
//        )
//    }
//
//    // MARK: - Equatable Conformance
//
//    public static func == (left: ImageFile, right: ImageFile) -> Bool {
//        let sameFileExtension = left.fileExtension == right.fileExtension
//        let sameName = left.name == right.name
//        let sameURLPath = left.urlPath == right.urlPath
//
//        guard sameFileExtension,
//              sameName,
//              sameURLPath else { return false }
//
//        return true
//    }
// }

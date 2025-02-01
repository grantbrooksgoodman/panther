//
//  SquareIconView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 28/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct SquareIconView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SquareIconView
    private typealias Floats = AppConstants.CGFloats.SquareIconView

    // MARK: - Properties

    private let configuration: Configuration

    // MARK: - Init

    public init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - View

    @ViewBuilder
    public var body: some View {
        let baseView = Rectangle()
            .frame(
                width: configuration.size.width,
                height: configuration.size.height
            )
            .foregroundStyle(configuration.backgroundColor)
            .cornerRadius(Floats.cornerRadius)

        if configuration.includesShadow {
            baseView
                .shadow(
                    color: Colors.shadow.opacity(Floats.shadowColorOpacity),
                    radius: Floats.shadowRadius,
                    x: 0,
                    y: Floats.shadowYOffset
                )
                .overlay { overlayView }
        } else {
            baseView
                .overlay { overlayView }
        }
    }

    private var overlayView: some View {
        Components.symbol(
            configuration.overlaySymbolName,
            foregroundColor: configuration.overlaySymbolForegroundColor,
            weight: configuration.overlaySymbolWeight,
            usesIntrinsicSize: false
        )
        .frame(
            width: (
                configuration.size.width * configuration.overlayFramePercentOfTotalSize
            ).rounded(.toNearestOrEven),
            height: (
                configuration.size.height * configuration.overlayFramePercentOfTotalSize
            ).rounded(.toNearestOrEven)
        )
    }

    // MARK: - UIImage Representation

    public static func image(_ configuration: Configuration) -> UIImage? {
        // swiftlint:disable:next identifier_name
        if let cachedSquareIconImagesForConfigurationEncodedHashes = _SquareIconImageCache.cachedSquareIconImagesForConfigurationEncodedHashes,
           let image = cachedSquareIconImagesForConfigurationEncodedHashes[configuration.encodedHash] {
            return image
        }

        let image = ImageRenderer(content: SquareIconView(configuration)).uiImage // swiftlint:disable:next identifier_name
        var cachedSquareIconImagesForConfigurationEncodedHashes = _SquareIconImageCache.cachedSquareIconImagesForConfigurationEncodedHashes ?? [:]
        cachedSquareIconImagesForConfigurationEncodedHashes[configuration.encodedHash] = image
        _SquareIconImageCache.cachedSquareIconImagesForConfigurationEncodedHashes = cachedSquareIconImagesForConfigurationEncodedHashes
        return image
    }
}

public enum SquareIconImageCache {
    public static func clearCache() {
        _SquareIconImageCache.clearCache()
    }
}

private enum _SquareIconImageCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable { // swiftlint:disable:next identifier_name
        case squareIconImagesForConfigurationEncodedHashes
    }

    // MARK: - Properties

    // swiftlint:disable:next identifier_name line_length
    @Cached(CacheKey.squareIconImagesForConfigurationEncodedHashes) fileprivate static var cachedSquareIconImagesForConfigurationEncodedHashes: [String: UIImage]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedSquareIconImagesForConfigurationEncodedHashes = nil
    }
}

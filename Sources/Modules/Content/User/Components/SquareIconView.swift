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

/// A rounded square icon with a configurable overlay.
///
/// Use ``SquareIconView`` to display a colored, rounded square containing an image resource,
/// a symbol, or text, as described by its configuration.
struct SquareIconView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SquareIconView
    private typealias Floats = AppConstants.CGFloats.SquareIconView

    // MARK: - Properties

    private let configuration: Configuration

    // MARK: - Init

    /// Creates a square icon with the given configuration.
    ///
    /// - Parameter configuration: The configuration that describes the icon.
    init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        Rectangle()
            .frame(
                width: configuration.size.width,
                height: configuration.size.height
            )
            .foregroundStyle(configuration.backgroundColor)
            .cornerRadius(Floats.cornerRadius)
            .if(configuration.includesShadow) {
                $0.shadow(
                    color: Colors.shadow.opacity(Floats.shadowColorOpacity),
                    radius: Floats.shadowRadius,
                    x: 0,
                    y: Floats.shadowYOffset
                )
            }
            .overlay { overlayView }
    }

    private var overlayView: some View {
        Group {
            switch configuration.overlay {
            case let .resource(
                resource,
                foregroundColor: foregroundColor,
                framePercentOfTotalSize: framePercentOfTotalSize,
                weight: weight
            ):
                Image(resource)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(weight)
                    .foregroundStyle(foregroundColor)
                    .frame(
                        width: (
                            configuration.size.width * framePercentOfTotalSize
                        ).rounded(.toNearestOrEven),
                        height: (
                            configuration.size.height * framePercentOfTotalSize
                        ).rounded(.toNearestOrEven)
                    )

            case let .symbol(
                name: name,
                foregroundColor: foregroundColor,
                framePercentOfTotalSize: framePercentOfTotalSize,
                weight: weight
            ):
                Components.symbol(
                    name,
                    foregroundColor: foregroundColor,
                    weight: weight,
                    usesIntrinsicSize: false
                )
                .frame(
                    width: (
                        configuration.size.width * framePercentOfTotalSize
                    ).rounded(.toNearestOrEven),
                    height: (
                        configuration.size.height * framePercentOfTotalSize
                    ).rounded(.toNearestOrEven)
                )

            case let .text(
                string: string,
                font: font,
                foregroundColor: foregroundColor
            ):
                Components.text(
                    string,
                    font: font,
                    foregroundColor: foregroundColor
                )
            }
        }
    }

    // MARK: - UIImage Representation

    /// Returns the icon for the given configuration, rendered as an image.
    ///
    /// Rendered images are cached in memory per configuration.
    ///
    /// - Parameter configuration: The configuration that describes the icon.
    ///
    /// - Returns: The rendered image; otherwise, `nil` if rendering fails.
    static func image(_ configuration: Configuration) -> UIImage? {
        if let cachedImage = _SquareIconImageCache.image(forEncodedHash: configuration.encodedHash) {
            return cachedImage
        }

        let image = ImageRenderer(content: SquareIconView(configuration)).uiImage
        _SquareIconImageCache.setImage(
            image,
            forEncodedHash: configuration.encodedHash
        )

        return image
    }
}

/// A namespace for managing the in-memory square icon image cache.
enum SquareIconImageCache {
    /// Removes every cached square icon image.
    static func clearCache() {
        _SquareIconImageCache.clearCache()
    }
}

private enum _SquareIconImageCache {
    // MARK: - Properties

    private static let cachedImagesForEncodedHashes = LockIsolated([String: UIImage]())

    // MARK: - Methods

    fileprivate static func clearCache() {
        cachedImagesForEncodedHashes.wrappedValue = [:]
    }

    fileprivate static func image(forEncodedHash encodedHash: String) -> UIImage? {
        cachedImagesForEncodedHashes.projectedValue[encodedHash]
    }

    /// Caches the given image for the encoded hash, or evicts the encoded hash's cached image
    /// when `nil` is passed.
    fileprivate static func setImage(
        _ image: UIImage?,
        forEncodedHash encodedHash: String
    ) {
        cachedImagesForEncodedHashes.projectedValue[encodedHash] = image
    }
}

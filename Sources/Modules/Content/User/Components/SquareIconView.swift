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

struct SquareIconView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SquareIconView
    private typealias Floats = AppConstants.CGFloats.SquareIconView

    // MARK: - Properties

    private let configuration: Configuration

    // MARK: - Init

    init(_ configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - View

    @ViewBuilder
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

    static func image(_ configuration: Configuration) -> UIImage? {
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

enum SquareIconImageCache {
    static func clearCache() {
        _SquareIconImageCache.clearCache()
    }
}

private enum _SquareIconImageCache {
    // MARK: - Properties

    // swiftlint:disable identifier_name
    private static let _cachedSquareIconImagesForConfigurationEncodedHashes = LockIsolated<[String: UIImage]?>(wrappedValue: nil)

    // MARK: - Computed Properties

    fileprivate static var cachedSquareIconImagesForConfigurationEncodedHashes: [String: UIImage]? {
        get { _cachedSquareIconImagesForConfigurationEncodedHashes.wrappedValue }
        set { _cachedSquareIconImagesForConfigurationEncodedHashes.wrappedValue = newValue }
    } // swiftlint:enable identifier_name

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedSquareIconImagesForConfigurationEncodedHashes = nil
    }
}

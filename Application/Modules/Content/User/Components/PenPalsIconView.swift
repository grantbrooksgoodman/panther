//
//  PenPalsIconView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 24/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct PenPalsIconView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.PenPalsIconView
    private typealias Floats = AppConstants.CGFloats.PenPalsIconView
    private typealias Strings = AppConstants.Strings.PenPalsIconView

    // MARK: - Properties

    private let backgroundColor: UIColor?
    private let includesShadow: Bool
    private let size: CGSize

    // MARK: - Computed Properties

    public static var image: UIImage? { image(backgroundColor: nil) }

    // MARK: - Init

    public init(
        size: CGSize = .init(
            width: AppConstants.CGFloats.PenPalsIconView.defaultFrameWidth,
            height: AppConstants.CGFloats.PenPalsIconView.defaultFrameHeight
        ),
        backgroundColor: UIColor? = nil,
        includesShadow: Bool = false
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.includesShadow = includesShadow
    }

    // MARK: - View

    @ViewBuilder
    public var body: some View {
        let baseView = Rectangle()
            .frame(
                width: size.width,
                height: size.height
            )
            .foregroundStyle(backgroundColor == nil ? .purple : Color(uiColor: backgroundColor!))
            .cornerRadius(Floats.cornerRadius)

        if includesShadow {
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
            Strings.symbolName,
            foregroundColor: Colors.overlaySymbolForeground,
            usesIntrinsicSize: false
        )
        .frame(
            width: size.width / Floats.overlayFrameWidthDivisor,
            height: size.height / Floats.overlayFrameHeightDivisor
        )
    }

    // MARK: - UIImage Representation

    public static func image(backgroundColor hexCode: Int? = nil) -> UIImage? {
        guard let hexCode else {
            if let cachedPenPalsIconImage = _PenPalsIconImageCache.cachedPenPalsIconImage {
                return cachedPenPalsIconImage
            }

            let image = ImageRenderer(content: PenPalsIconView()).uiImage
            _PenPalsIconImageCache.cachedPenPalsIconImage = image
            return image
        }

        // swiftlint:disable:next identifier_name
        if let cachedPenPalsIconImagesForBackgroundColorHexCodes = _PenPalsIconImageCache.cachedPenPalsIconImagesForBackgroundColorHexCodes,
           let image = cachedPenPalsIconImagesForBackgroundColorHexCodes[hexCode] {
            return image
        }

        let image = ImageRenderer(content: PenPalsIconView(backgroundColor: .init(hex: hexCode))).uiImage // swiftlint:disable:next identifier_name
        var cachedPenPalsIconImagesForBackgroundColorHexCodes = _PenPalsIconImageCache.cachedPenPalsIconImagesForBackgroundColorHexCodes ?? [:]
        cachedPenPalsIconImagesForBackgroundColorHexCodes[hexCode] = image
        return image
    }
}

public enum PenPalsIconImageCache {
    public static func clearCache() {
        _PenPalsIconImageCache.clearCache()
    }
}

private enum _PenPalsIconImageCache {
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case penPalsIconImage // swiftlint:disable:next identifier_name
        case penPalsIconImagesForBackgroundColorHexCodes
    }

    // MARK: - Properties

    @Cached(CacheKey.penPalsIconImage) fileprivate static var cachedPenPalsIconImage: UIImage? // swiftlint:disable:next identifier_name
    @Cached(CacheKey.penPalsIconImagesForBackgroundColorHexCodes) fileprivate static var cachedPenPalsIconImagesForBackgroundColorHexCodes: [Int: UIImage]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedPenPalsIconImage = nil
        cachedPenPalsIconImagesForBackgroundColorHexCodes = nil
    }
}

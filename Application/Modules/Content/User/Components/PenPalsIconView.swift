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

    @MainActor
    public static var image: Image {
        .init(uiImage: ImageRenderer(content: PenPalsIconView()).uiImage ?? .init())
    }

    private let includesShadow: Bool
    private let size: CGSize

    // MARK: - Init

    public init(
        size: CGSize = .init(
            width: AppConstants.CGFloats.PenPalsIconView.defaultFrameWidth,
            height: AppConstants.CGFloats.PenPalsIconView.defaultFrameHeight
        ),
        includesShadow: Bool = false
    ) {
        self.size = size
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
            .foregroundStyle(Color.purple)
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
}

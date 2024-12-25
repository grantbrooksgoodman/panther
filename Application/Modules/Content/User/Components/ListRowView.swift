//
//  ListRowView.swift
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

public struct ListRowView: View {
    // MARK: - Types

    public enum Configuration {
        /* MARK: Cases */

        case button(showsChevron: Bool = false, action: () -> Void)
        case `switch`(isToggled: Binding<Bool>)
        case destination(_ view: any View)

        /* MARK: Properties */

        public var buttonAction: (() -> Void)? {
            switch self {
            case let .button(showsChevron: _, action: action): return action
            case .destination: return nil
            case .switch: return nil
            }
        }

        public var buttonShowsChevron: Bool? {
            switch self {
            case let .button(showsChevron: showsChevron, action: _): return showsChevron
            case .destination: return nil
            case .switch: return nil
            }
        }

        public var destination: (any View)? {
            switch self {
            case .button: return nil
            case let .destination(view: view): return view
            case .switch: return nil
            }
        }

        public var isSwitchToggled: Binding<Bool>? {
            switch self {
            case .button: return nil
            case .destination: return nil
            case let .switch(isToggled: isToggled): return isToggled
            }
        }
    }

    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ListRowView
    private typealias Floats = AppConstants.CGFloats.ListRowView
    private typealias Strings = AppConstants.Strings.ListRowView

    // MARK: - Properties

    private let configuration: Configuration
    private let image: Image?
    private let isEnabled: Bool
    private let title: String

    // MARK: - Init

    public init(
        _ configuration: Configuration,
        title: String,
        image: Image? = nil,
        isEnabled: Bool = true
    ) {
        self.configuration = configuration
        self.title = title
        self.image = image
        self.isEnabled = isEnabled
    }

    // MARK: - View

    public var body: some View {
        contentView
            .clipShape(
                RoundedRectangle(
                    cornerSize: .init(
                        width: Floats.clipShapeRoundedRectangleCornerSizeFrameWidth,
                        height: Floats.clipShapeRoundedRectangleCornerSizeFrameHeight
                    ),
                    style: .continuous
                )
            )
            .disabled(!isEnabled)
    }

    @ViewBuilder
    private var contentView: some View {
        switch configuration {
        case .button:
            Button {
                configuration.buttonAction?()
            } label: {
                labelView
            }
            .buttonStyle(ListRowButtonStyle())

        case let .destination(view):
            NavigationLink {
                AnyView(view)
            } label: {
                labelView
            }
            .buttonStyle(ListRowButtonStyle())

        case .switch:
            labelView
                .background(ThemeService.isDarkModeActive ? Colors.darkBackground : Colors.lightBackground)
        }
    }

    private var labelView: some View {
        HStack {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(Floats.imageCornerRadius)
                    .frame(
                        width: Floats.imageFrameWidth,
                        height: Floats.imageFrameHeight
                    )
                    .padding(.leading, Floats.imageLeadingPadding)
            }

            Components.text(
                title,
                foregroundColor: isEnabled ? .titleText : Colors.titleLabelDisabledForeground
            )
            .padding(.leading, image == nil ? 0 : Floats.titleLabelLeadingPadding)

            Spacer()

            if let isSwitchToggled = configuration.isSwitchToggled {
                Toggle("", isOn: isSwitchToggled)
                    .labelsHidden()
            } else if configuration.buttonShowsChevron == true || configuration.destination != nil {
                Components.symbol(
                    Strings.chevronImageSystemName,
                    foregroundColor: .init(
                        uiColor: isEnabled ? ((
                            ThemeService.isDarkModeActive ? .subtitleText : .subtitleText.lighter()
                        ) ?? .subtitleText) : .disabled
                    ),
                    weight: .semibold,
                    usesIntrinsicSize: false
                )
                .frame(
                    maxWidth: Floats.chevronImageFrameMaxWidth,
                    maxHeight: Floats.chevronImageFrameMaxHeight
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Floats.verticalPadding)
    }
}

private struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? (
                    ThemeService.isDarkModeActive ? .init(uiColor: .init(hex: 0x3A3A3C)) : .init(uiColor: .init(hex: 0xD1D1D6))
                ) : ThemeService.isDarkModeActive ? Color(uiColor: .init(hex: 0x2A2A2C)) : .white
            )
    }
}

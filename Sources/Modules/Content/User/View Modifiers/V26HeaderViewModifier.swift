//
//  V26HeaderViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

private struct V26HeaderViewModifier: ViewModifier {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.V26HeaderViewModifier
    private typealias Strings = AppConstants.Strings.V26HeaderViewModifier

    // MARK: - Dependencies

    @Dependency(\.uiApplication.mainScreen.bounds.width) private var screenWidth: CGFloat

    // MARK: - Properties

    private let attributes: HeaderView.Attributes
    private let centerItem: HeaderView.CenterItemType?
    private let leftItem: HeaderView.PeripheralButtonType?
    private let popGestureAction: (() -> Void)?
    private let rightItem: HeaderView.PeripheralButtonType?
    private let usesV26Attributes: Bool

    // MARK: - Computed Properties

    private var imageMaxWidth: CGFloat { screenWidth / Floats.imageMaxWidthDivisor }
    private var isThemed: Bool { attributes.appearance == .themed }
    private var navigationBarAppearance: NavigationBarAppearance {
        let configuration: NavigationBarConfiguration = .init(
            titleColor: textColor ?? .navigationBarTitle,
            backgroundColor: .clear,
            barButtonItemColor: textColor ?? .accent,
            showsDivider: attributes.showsDivider
        )

        return .custom(
            configuration,
            scrollEdgeConfig: configuration
        )
    }

    private var textColor: UIColor? {
        var colors = Set<Color>()

        if let leftItemForegroundColor = leftItem?.foregroundColor {
            colors.insert(leftItemForegroundColor)
        }

        if let centerItem {
            if let subtitleForegroundColor = centerItem.subtitleForegroundColor {
                colors.insert(subtitleForegroundColor)
            }

            if let titleForegroundColor = centerItem.titleForegroundColor {
                colors.insert(titleForegroundColor)
            }
        }

        if let rightItemForegroundColor = rightItem?.foregroundColor {
            colors.insert(rightItemForegroundColor)
        }

        guard colors.count == 1,
              let color = colors.first else { return nil }

        return .init(color)
    }

    // MARK: - Init

    init(
        leftItem: HeaderView.PeripheralButtonType?,
        centerItem: HeaderView.CenterItemType?,
        rightItem: HeaderView.PeripheralButtonType?,
        attributes: HeaderView.Attributes,
        popGestureAction: (() -> Void)?,
        usesV26Attributes: Bool
    ) {
        self.leftItem = leftItem
        self.centerItem = centerItem
        self.rightItem = rightItem
        self.attributes = UIApplication.v26FeaturesEnabled && usesV26Attributes ? .init(
            appearance: .custom(backgroundColor: .clear),
            showsDivider: false,
            sizeClass: attributes.sizeClass
        ) : attributes
        self.popGestureAction = popGestureAction
        self.usesV26Attributes = usesV26Attributes
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .if(
                UIApplication.v26FeaturesEnabled,
                { content in
                    NavigationWindow(
                        displayMode: .inline,
                        toolbarItems: [
                            leadingToolbarItem,
                            principalToolbarItem,
                            trailingToolbarItem,
                        ].compactMap { $0 }
                    ) {
                        ZStack(alignment: .top) {
                            Color.clear
                                .frame(width: .zero, height: .zero)
                                .ignoresSafeArea(edges: .top)
                                .navigationBarAppearance(navigationBarAppearance)

                            content

                            Rectangle()
                                .fill(Color(uiColor: attributes.appearance.backgroundColor))
                                .frame(height:
                                    NavigationBar.height + Floats.navigationBarHeightIncrement
                                )
                                .ignoresSafeArea(edges: .top)
                        }
                    }
                },
                else: {
                    $0
                        .header(
                            leftItem: leftItem,
                            centerItem,
                            rightItem: rightItem,
                            attributes: attributes,
                            popGestureAction: popGestureAction
                        )
                }
            )
    }

    // MARK: - Toolbar Items

    private var leadingToolbarItem: NavigationWindow.Toolbar.Item? {
        guard let leftItem else { return nil }
        return .init(placement: .topBarLeading) {
            peripheralToolbarButton(for: leftItem, isLeadingItem: true)
        }
    }

    private var principalToolbarItem: NavigationWindow.Toolbar.Item? {
        guard let centerItem,
              let navigationTitle = centerItem.navigationTitle else { return nil }

        return .init(placement: .principal) {
            Components.text(
                navigationTitle,
                font: .systemSemibold,
                foregroundColor: centerItem.titleForegroundColor ?? .navigationBarTitle
            )
        }
    }

    private var trailingToolbarItem: NavigationWindow.Toolbar.Item? {
        guard let rightItem else { return nil }
        return .init(placement: .topBarTrailing) {
            peripheralToolbarButton(for: rightItem, isLeadingItem: false)
        }
    }

    // MARK: - Auxiliary

    private func peripheralToolbarButton(
        for type: HeaderView.PeripheralButtonType,
        isLeadingItem: Bool
    ) -> some View {
        Group {
            switch type {
            case let .image(attributes):
                Button {
                    attributes.action()
                } label: {
                    attributes.image.image
                        .resizable()
                        .scaledToFit()
                        .fontWeight(attributes.image.weight)
                        .foregroundStyle(isThemed ? (attributes.isEnabled ? .accent : .disabled) : attributes.image.foregroundColor)
                        .ifLet(attributes.image.size) { image, size in
                            image
                                .frame(
                                    width: size.width > imageMaxWidth ? nil : size.width,
                                    height: size.height > Floats.toolbarButtonHeight ? nil : size.height
                                )
                        }
                        .frame(
                            maxWidth: imageMaxWidth,
                            maxHeight: Floats.toolbarButtonHeight,
                            alignment: isLeadingItem ? .leading : .trailing
                        )
                }
                .disabled(!attributes.isEnabled)

            case let .text(attributes):
                if attributes.text.string == Localized(.cancel).wrappedValue || attributes.text.string == Localized(.done).wrappedValue {
                    Components.button(
                        symbolName: attributes.text.string == Localized(.cancel).wrappedValue ?
                            Strings.cancelToolbarButtonImageSystemName :
                            Strings.doneToolbarButtonImageSystemName,
                        foregroundColor: isThemed ? (attributes.isEnabled ? .accent : .disabled) : attributes.text.foregroundColor,
                        weight: .semibold,
                        usesIntrinsicSize: false
                    ) {
                        attributes.action()
                    }
                    .disabled(!attributes.isEnabled)
                    .frame(
                        width: Floats.toolbarButtonWidth,
                        height: Floats.toolbarButtonHeight
                    )
                } else {
                    Button {
                        attributes.action()
                    } label: {
                        Text(attributes.text.string)
                            .font(attributes.text.font)
                            .foregroundStyle(isThemed ? (attributes.isEnabled ? .accent : .disabled) : attributes.text.foregroundColor)
                            .lineLimit(1)
                            .minimumScaleFactor(Floats.toolbarButtonLabelMinimumScaleFactor)
                            .padding(.horizontal, Floats.toolbarButtonLabelHorizontalPadding)
                    }
                    .disabled(!attributes.isEnabled)
                }
            }
        }
    }
}

extension View {
    /// - Parameter attributes: Choosing a themed `appearance` value overrides all color values to those of the system theme.
    func v26Header(
        leftItem: HeaderView.PeripheralButtonType? = nil,
        _ centerItem: HeaderView.CenterItemType? = nil,
        rightItem: HeaderView.PeripheralButtonType? = nil,
        attributes: HeaderView.Attributes = .init(),
        popGestureAction: (() -> Void)? = nil,
        usesV26Attributes: Bool = true
    ) -> some View {
        modifier(
            V26HeaderViewModifier(
                leftItem: leftItem,
                centerItem: centerItem,
                rightItem: rightItem,
                attributes: attributes,
                popGestureAction: popGestureAction,
                usesV26Attributes: usesV26Attributes
            )
        )
    }
}

private extension HeaderView.CenterItemType {
    var navigationTitle: String? {
        switch self {
        case .image: return nil
        case let .text(titleTextAttributes, subtitle: _): return titleTextAttributes.string
        }
    }

    var subtitleForegroundColor: Color? {
        switch self {
        case .image: return nil
        case let .text(_, subtitle: subtitleTextAttributes): return subtitleTextAttributes?.foregroundColor
        }
    }

    var titleForegroundColor: Color? {
        switch self {
        case .image: return nil
        case let .text(titleTextAttributes, subtitle: _): return titleTextAttributes.foregroundColor
        }
    }
}

private extension HeaderView.PeripheralButtonType {
    var foregroundColor: Color? {
        switch self {
        case .image: return nil
        case let .text(attributes): return attributes.text.foregroundColor
        }
    }
}

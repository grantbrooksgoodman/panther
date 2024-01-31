//
//  NavigationBarColorViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI
import UIKit

private struct NavigationBarColorViewModifier: ViewModifier {
    // MARK: - Properties

    private let background: Color
    private let titleText: Color?

    // MARK: - Init

    public init(background: Color, titleText: Color?) {
        self.background = background
        self.titleText = titleText

        var titleTextUiColor = UIColor.white
        if let titleText {
            titleTextUiColor = UIColor(titleText)
        }

        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithTransparentBackground()

        coloredAppearance.backgroundColor = UIColor(background)
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: titleTextUiColor]
        coloredAppearance.shadowColor = .clear
        coloredAppearance.titleTextAttributes = [.foregroundColor: titleTextUiColor]

        UINavigationBar.appearance().compactAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().tintColor = titleTextUiColor
    }

    // MARK: - Body

    public func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                GeometryReader { geometry in
                    background
                        .frame(height: geometry.safeAreaInsets.top)
                        .edgesIgnoringSafeArea(.top)
                    Spacer()
                }
            }
        }
    }
}

public extension View {
    @ViewBuilder
    func navigationBarColor(background: Color, titleText: Color?) -> some View {
        modifier(NavigationBarColorViewModifier(background: background, titleText: titleText))
    }
}

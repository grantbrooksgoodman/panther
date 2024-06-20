//
//  SplashPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import ComponentKit
import CoreArchitecture

public struct SplashPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SplashPageView
    private typealias Floats = AppConstants.CGFloats.SplashPageView

    // MARK: - Properties

    @State private var rebuildingIndicesLabelOpacity: CGFloat = 1
    @StateObject private var viewModel: ViewModel<SplashPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SplashPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        VStack {
            Image(.hello)
                .resizable()
                .renderingMode((ThemeService.isDarkModeActive || !ThemeService.isDefaultThemeApplied) ? .template : .original)
                .foregroundColor((ThemeService.isDarkModeActive || !ThemeService.isDefaultThemeApplied) ? Colors.imageDarkForeground : .none)
                .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                .padding(.bottom, Floats.padding)

            if viewModel.isRebuildingIndices {
                Components.text(
                    viewModel.rebuildingIndicesLabelText,
                    font: .systemLight(scale: .custom(Floats.rebuildingIndicesLabelFontSize)),
                    foregroundColor: .subtitleText
                )
                .opacity(rebuildingIndicesLabelOpacity)
                .padding(.vertical, Floats.padding)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1)
                            .repeatForever(autoreverses: true)
                    ) {
                        rebuildingIndicesLabelOpacity = Floats.rebuildingIndicesLabelAnimationOpacity
                    }
                }
            }

            ProgressView()
                .controlSize(.large)
                .dynamicTypeSize(.large)
                .scaleEffect(.init(Floats.progressViewScaleEffect))
                .padding(.top, Floats.padding)
        }
        .fadeIn(delay: .milliseconds(Floats.fadeInDelayMilliseconds))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredStatusBarStyle(ThemeService.isDefaultThemeApplied ? .default : .lightContent)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}

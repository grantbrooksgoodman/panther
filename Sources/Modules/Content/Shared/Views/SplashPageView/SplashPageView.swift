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

/* Proprietary */
import AppSubsystem
import ComponentKit

struct SplashPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SplashPageView
    private typealias Floats = AppConstants.CGFloats.SplashPageView
    private typealias Strings = AppConstants.Strings.SplashPageView

    // MARK: - Dependencies

    @ObservedDependency(\.splashPageViewService) private var viewService: SplashPageViewService

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<SplashPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<SplashPageReducer>) {
        _viewModel = .init(
            wrappedValue: viewModel
                .observing(
                    SharedEvent(\.networkActivityOccurred)
                        .wrappedValue
                        .events
                ) { _ in .bundleInitializationProgressOccurred }
        )
    }

    // MARK: - View

    var body: some View {
        VStack {
            ZStack {
                GIFImage(
                    Strings.gifImageName,
                    isActive: viewService.loadingIndicatorStyle == .bar
                )
                .frame(
                    width: Floats.imageFrameWidth,
                    height: Floats.imageFrameHeight
                )
                .opacity(viewService.loadingIndicatorStyle == .bar ? 1 : 0)

                ThemedView {
                    Image(.hello)
                        .resizable()
                        .renderingMode(
                            (ThemeService.isDarkModeActive || !ThemeService.isAppDefaultThemeApplied) ? .template : .original
                        )
                        .foregroundColor(
                            (ThemeService.isDarkModeActive || !ThemeService.isAppDefaultThemeApplied) ? Colors.imageDarkForeground : .none
                        )
                        .frame(
                            width: Floats.imageFrameWidth,
                            height: Floats.imageFrameHeight
                        )
                }
                .opacity(viewService.loadingIndicatorStyle == .bar ? 0 : 1)
            }
            .padding(.bottom, Floats.padding)

            progressBar

            if viewService.loadingIndicatorStyle == .spinner {
                ProgressView()
                    .controlSize(.large)
                    .dynamicTypeSize(.large)
                    .scaleEffect(.init(Floats.activityIndicatorScaleEffect))
                    .padding(.top, Floats.padding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredStatusBarStyle(
            .appAware,
            restoreOnDisappear: !Application.isInPrevaricationMode
        )
        .onAppear {
            Application.loadStartDate = .now
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    private var progressBar: some View {
        ProgressView(value: viewService.initializationProgress)
            .animation(.easeIn, value: viewService.initializationProgress)
            .controlSize(.large)
            .dynamicTypeSize(.large)
            .tint(Colors.progressBarTint)
            .opacity(viewService.loadingIndicatorStyle == .bar ? 1 : 0)
            .padding(.horizontal, Floats.progressBarHorizontalPadding)
            .fadeIn(delay: .milliseconds(
                Floats.progressBarFadeInDelayMilliseconds
            ))
    }
}

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
import Redux

public struct SplashPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SplashPageView
    private typealias Floats = AppConstants.CGFloats.SplashPageView
    private typealias Strings = AppConstants.Strings.SplashPageView

    // MARK: - Properties

    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @StateObject private var viewModel: ViewModel<SplashPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SplashPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        VStack {
            Image(uiImage: UIImage(named: Strings.imageName)!)
                .resizable()
                .renderingMode(colorScheme == .dark ? .template : .original)
                .foregroundColor(colorScheme == .dark ? Colors.imageDarkForeground : .none)
                .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                .padding(.bottom, Floats.padding)

            ProgressView()
                .controlSize(.large)
                .scaleEffect(.init(Floats.progressViewScaleEffect))
                .padding(.top, Floats.padding)
        }
        .fadeIn(delay: .milliseconds(Floats.fadeInDelayMilliseconds))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}

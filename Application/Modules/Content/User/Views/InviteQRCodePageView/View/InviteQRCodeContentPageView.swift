//
//  InviteQRCodeContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct InviteQRCodeContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.InviteQRCodePageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<InviteQRCodePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<InviteQRCodePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            VStack {
                Components.text(
                    viewModel.strings.value(for: .instructionLabelText),
                    font: .systemSemibold(scale: .large)
                )
                .multilineTextAlignment(.center)
                .padding(.bottom, Floats.imageBottomPadding)
                .padding(.horizontal, Floats.imageHorizontalPadding)

                if let qrCodeImage = viewModel.qrCodeImage {
                    Image(uiImage: qrCodeImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .header(
                rightItem: .doneButton { viewModel.send(.doneButtonTapped) },
                attributes: .init(sizeClass: .sheet)
            )
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.InviteQRCodePageViewStringKey) -> String {
        (first(where: { $0.key == .inviteQRCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}

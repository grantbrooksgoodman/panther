//
//  InstructionView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import ComponentKit

public struct InstructionView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.InstructionView
    private typealias Floats = AppConstants.CGFloats.InstructionView

    // MARK: - Properties

    private let strings: InstructionViewStrings
    @Environment(\.keyWindowSize) private var keyWindowSize: CGSize

    // MARK: - Computed Properties

    private var halfOfScreenWidth: CGFloat { keyWindowSize.width / Floats.keyWindowSizeWidthDivisor }

    // MARK: - Init

    public init(_ strings: InstructionViewStrings) {
        self.strings = strings
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            HStack {
                VStack(alignment: .leading) {
                    Components.text(
                        strings.titleLabelText,
                        font: .systemBold(scale: .large),
                        foregroundColor: .titleText
                    )
                    .padding(.bottom, Floats.titleLabelBottomPadding)
                    .minimumScaleFactor(Floats.titleLabelMinimumScaleFactor)

                    Components.text(
                        strings.subtitleLabelText,
                        font: .system(scale: .custom(Floats.subtitleLabelFontSize)),
                        foregroundColor: Colors.subtitleLabelForeground
                    )
                    .minimumScaleFactor(Floats.subtitleLabelMinimumScaleFactor)
                }
                .frame(
                    width: halfOfScreenWidth,
                    height: Floats.frameHeight,
                    alignment: .topLeading
                )
                .padding(.leading, Floats.leadingPadding)
                .padding(.top, Floats.topPadding)

                Spacer()
            }
        }
    }
}

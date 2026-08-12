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

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A header that displays a title and subtitle introducing an onboarding page.
///
/// Use ``InstructionView`` at the top of an onboarding page to tell the user what the page is for
/// and what they should do next. The view renders the title and subtitle from the given
/// ``InstructionViewStrings`` value, leading-aligned and constrained to the leading half of the
/// screen's width.
///
/// ```swift
/// VStack {
///     InstructionView(viewModel.instructionViewStrings)
///
///     // Page content.
/// }
/// ```
///
/// - Note: The view displays the given strings verbatim. Perform any localization before creating
///   the ``InstructionViewStrings`` value.
struct InstructionView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.InstructionView
    private typealias Floats = AppConstants.CGFloats.InstructionView

    // MARK: - Dependencies

    @Dependency(\.uiApplication.mainScreen.bounds.width) private var screenWidth: CGFloat

    // MARK: - Properties

    private let strings: InstructionViewStrings

    // MARK: - Computed Properties

    private var halfOfScreenWidth: CGFloat {
        screenWidth / Floats.screenWidthDivisor
    }

    // MARK: - Init

    /// Creates an instruction view that displays the given strings.
    ///
    /// - Parameter strings: The title and subtitle text to display.
    init(_ strings: InstructionViewStrings) {
        self.strings = strings
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
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
                    alignment: .topLeading
                )
                .frame(maxHeight: Floats.frameMaxHeight)
                .padding(.leading, Floats.leadingPadding)
                .padding(.top, Floats.topPadding)
                .fixedSize()

                Spacer()
            }
        }
    }
}

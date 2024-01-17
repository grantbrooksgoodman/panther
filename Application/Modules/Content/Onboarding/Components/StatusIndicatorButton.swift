//
//  StatusIndicatorButton.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public struct StatusIndicatorButton: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.StatusIndicatorButton
    private typealias Floats = AppConstants.CGFloats.StatusIndicatorButton
    private typealias Strings = AppConstants.Strings.StatusIndicatorButton

    // MARK: - Properties

    private let action: () -> Void
    private let isCompleted: Bool?
    private let text: String

    // MARK: - Computed Properties

    private var imageSecondaryForegroundColor: Color {
        guard let isCompleted else { return Colors.undeterminedStatusImageSecondaryForeground }
        return isCompleted ? Colors.grantedStatusImageSecondaryForeground : Colors.deniedStatusImageSecondaryForeground
    }

    private var imageSystemName: String {
        guard let isCompleted else { return Strings.undeterminedStatusImageSystemName }
        return isCompleted ? Strings.grantedStatusImageSystemName : Strings.deniedStatusImageSystemName
    }

    // MARK: - Init

    public init(
        _ text: String,
        action: @escaping () -> Void,
        isCompleted: Bool?
    ) {
        self.text = text
        self.action = action
        self.isCompleted = isCompleted
    }

    // MARK: - View

    public var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: imageSystemName)
                    .padding(.trailing, Floats.imageTrailingPadding)
                    .font(.system(size: Floats.imageSystemFontSize))
                    .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                    .foregroundStyle(.white, imageSecondaryForegroundColor)

                Text(text)
                    .foregroundStyle(isCompleted == nil ? Colors.undeterminedStatusLabelForeground : Colors.determinedStatusLabelForeground)
                    .font(.system(size: Floats.labelFontSize))
                    .bold()
            }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .disabled(isCompleted == nil ? false : true)
        .foregroundStyle(Colors.foreground)
    }
}

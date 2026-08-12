//
//  DataUsageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/12/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A labeled progress bar showing data usage against a limit.
///
/// Use ``DataUsageView`` to display a usage amount as a percentage and formatted size above a
/// progress bar whose color reflects how close the usage is to the limit.
struct DataUsageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.DataUsageView
    private typealias Floats = AppConstants.CGFloats.DataUsageView
    private typealias Strings = AppConstants.Strings.DataUsageView

    // MARK: - Properties

    private let dataUsageInKilobytes: Int
    private let labelText: String
    private let usageLimitInKilobytes: Int

    // MARK: - Computed Properties

    private var percentLabelText: String {
        .init(Int((
            usageFraction * Floats.percentLabelFractionMultiplier
        ).rounded()))
    }

    private var progressBarColor: Color {
        if usageFraction < Floats.lowUsageThreshold {
            return Colors.lowUsage
        } else if usageFraction < Floats.mediumUsageThreshold {
            return Colors.mediumUsage
        }

        return Colors.highUsage
    }

    private var usageFraction: Double {
        Double(dataUsageInKilobytes) / Double(usageLimitInKilobytes)
    }

    private var usageLabelText: String {
        let usageInMB = String(
            format: "%.2f",
            Double(dataUsageInKilobytes) / Floats.usageInMegabytesDivisor
        )

        if usageInMB == Strings.zero {
            return "\(dataUsageInKilobytes)kb"
        }

        return "\(usageInMB)mb"
    }

    // MARK: - Init

    /// Creates a data usage view.
    ///
    /// - Parameters:
    ///   - labelText: The text the label displays before the usage figures.
    ///   - dataUsageInKilobytes: The amount of data used, in kilobytes.
    ///   - usageLimitInKilobytes: The limit against which usage is measured, in kilobytes.
    init(
        labelText: String = Strings.defaultLabelText,
        dataUsageInKilobytes: Int,
        usageLimitInKilobytes: Int = Int(Floats.defaultUsageLimit)
    ) {
        self.labelText = labelText
        self.dataUsageInKilobytes = dataUsageInKilobytes
        self.usageLimitInKilobytes = usageLimitInKilobytes
    }

    // MARK: - Body

    /// The content and behavior of the view.
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 0
        ) {
            Components.text(
                "\(labelText): \(percentLabelText)% (\(usageLabelText))",
                font: .system(scale: .small),
                foregroundColor: .subtitleText
            )
            .padding(
                .bottom,
                Floats.labelBottomPadding
            )

            ProgressView(value: usageFraction)
                .tint(progressBarColor)
        }
        .padding(.horizontal)
    }
}

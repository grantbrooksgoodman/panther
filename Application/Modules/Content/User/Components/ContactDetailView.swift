//
//  ContactDetailView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ContactDetailView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ContactDetailView
    private typealias Floats = AppConstants.CGFloats.ContactDetailView
    private typealias Strings = AppConstants.Strings.ContactDetailView

    // MARK: - Properties

    // String
    private let subtitleLabelText: String?
    private let titleLabelText: String

    // Other
    private let image: UIImage?

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    // MARK: - Init

    public init(
        titleLabelText: String,
        subtitleLabelText: String?,
        image: UIImage?
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
        self.image = image
    }

    // MARK: - View

    public var body: some View {
        HStack(alignment: .center) {
            AvatarImageView(image)
                .padding(.trailing, Floats.avatarImageViewTrailingPadding)

            VStack(alignment: .leading) {
                Text(titleLabelText)
                    .font(.sanFrancisco(.semibold, size: Floats.titleLabelFontSize))
                    .foregroundStyle(Color.titleText)
                    .padding(.bottom, 0)

                if let subtitleLabelText {
                    Text(subtitleLabelText)
                        .font(.sanFrancisco(size: Floats.subtitleLabelFontSize))
                        .foregroundStyle(Color.titleText)
                }
            }

            Spacer()

            if subtitleLabelText != nil {
                Image(systemName: Strings.chevronImageSystemName)
                    .foregroundStyle(Color.subtitleText)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Colors.darkBackground : Colors.lightBackground)
        .cornerRadius(Floats.cornerRadius)
    }
}

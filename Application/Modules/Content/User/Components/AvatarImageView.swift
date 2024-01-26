//
//  AvatarImageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public struct AvatarImageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.AvatarImageView
    private typealias Floats = AppConstants.CGFloats.AvatarImageView
    private typealias Strings = AppConstants.Strings.AvatarImageView

    // MARK: - Properties

    private let image: UIImage?

    // MARK: - Init

    public init(_ image: UIImage?) {
        self.image = image
    }

    // MARK: - View

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(Circle())
            } else {
                Image(systemName: Strings.defaultImageSystemName)
                    .foregroundStyle(Colors.defaultImageForeground)
            }
        }
        .font(.system(size: Floats.systemFontSize))
        .frame(width: Floats.frameWidth, height: Floats.frameHeight)
        .cornerRadius(Floats.cornerRadius)
    }
}

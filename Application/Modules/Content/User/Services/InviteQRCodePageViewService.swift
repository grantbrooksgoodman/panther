//
//  InviteQRCodePageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import CoreArchitecture

public struct InviteQRCodePageViewService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.metadata.appShareLink) private var appShareLink: URL?
    @Dependency(\.uiApplication.mainScreen) private var mainScreen: UIScreen?

    // MARK: - Properties

    public var appShareQRCodeImage: UIImage? {
        guard let appShareLink else { return nil }
        return generateQRCode(from: appShareLink.absoluteString, outputSize: .init(width: 500, height: 500))
    }

    // MARK: - Auxiliary

    private func generateQRCode(
        from string: String,
        outputSize: CGSize
    ) -> UIImage? {
        guard let data = string.data(using: .isoLatin1),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }

        filter.setValue("Q", forKey: "inputCorrectionLevel")
        filter.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter.outputImage else { return nil }

        let imageRendererFormat = UIGraphicsImageRendererFormat()
        imageRendererFormat.scale = (mainScreen ?? .main).scale
        let imageRenderer = UIGraphicsImageRenderer(size: outputSize, format: imageRendererFormat)

        return imageRenderer
            .image { _ in
                UIImage(
                    ciImage: outputImage
                        .transformed(
                            by: .init(
                                scaleX: outputSize.width / outputImage.extent.integral.width,
                                y: outputSize.height / outputImage.extent.integral.height
                            )
                        )
                )
                .draw(in: .init(origin: .zero, size: outputSize))
            }
    }
}

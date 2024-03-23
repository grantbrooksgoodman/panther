//
//  UIImage+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public extension UIImage {
    func dataCompressed(toKB kilobytes: Int, toleratedMarginOfError: CGFloat = 0.2) -> Data? {
        var compressedData: Data?
        var currentKilobytes = kilobytes

        while compressedData == nil {
            compressedData = _dataCompressed(toKB: currentKilobytes, toleratedMarginOfError: toleratedMarginOfError)
            currentKilobytes -= 1
            guard currentKilobytes > 1 else { break }
        }

        return compressedData
    }

    func resized(toPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let imageSize = CGSize(width: size.width * percentage, height: size.height * percentage)
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            draw(in: .init(origin: .zero, size: imageSize))
        }
    }

    private func _dataCompressed(toKB kilobytes: Int, toleratedMarginOfError: CGFloat) -> Data? {
        let bytes = kilobytes * 1024
        let step: CGFloat = 0.05

        var currentCompression: CGFloat = 1.0
        var currentImage = self
        var didComplete = false

        while !didComplete {
            guard currentCompression > 0 else { break }

            if let data = currentImage.jpegData(compressionQuality: 1.0) {
                guard !(data.count < Int(CGFloat(bytes) * (1 + toleratedMarginOfError))) else {
                    didComplete = true
                    return data
                }

                let ratio = data.count / bytes
                let multiplier = CGFloat((ratio / 5) + 1)
                currentCompression -= (step * multiplier)
            }

            guard let newImage = currentImage.resized(toPercentage: currentCompression) else { break }
            currentImage = newImage
        }

        return nil
    }
}

//
//  Duration+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Duration {
    /// Returns a transfer timeout scaled to the size of the file at the given URL.
    ///
    /// The timeout scales linearly with file size, assuming a worst-case sustained transfer rate
    /// of roughly 1 Mbps, and falls back to the maximum when the file size cannot be determined.
    ///
    /// - Parameter fileURL: The URL of the file to compute a timeout for.
    ///
    /// - Returns: The transfer timeout.
    static func transferTimeout(
        forItemAt fileURL: URL
    ) -> Duration {
        typealias Floats = AppConstants.CGFloats.CommonNetworkingExtensions.Duration

        guard let fileSizeBytes = (
            try? fileURL.resourceValues(
                forKeys: [.fileSizeKey]
            )
        )?.fileSize else {
            return .seconds(Floats.transferTimeoutMaxSeconds)
        }

        return .seconds(min(
            Floats.transferTimeoutMaxSeconds,
            Floats.transferTimeoutFloorSeconds + Floats.transferTimeoutSecondsPerMegabyte * (Double(fileSizeBytes) / Floats.transferTimeoutBytesPerMegabyte)
        ))
    }
}

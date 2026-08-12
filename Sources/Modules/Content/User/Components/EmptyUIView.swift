//
//  EmptyUIView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 09/02/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

// NIT: Seems to fix disappearing list refresh control, but unsure of efficacy.
/// An empty, zero-sized UIKit view for embedding in SwiftUI hierarchies.
struct EmptyUIView: UIViewRepresentable {
    // MARK: - Make UIView

    /// Creates an empty view with a zero-sized frame.
    func makeUIView(context: Context) -> UIView {
        .init(frame: .zero)
    }

    // MARK: - Update UIView

    /// Does nothing; the view requires no updates.
    func updateUIView(
        _ uiView: UIView,
        context: Context
    ) {}
}

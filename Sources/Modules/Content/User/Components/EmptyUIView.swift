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

// TODO: Audit this; seems to fix disappearing list refresh control, but unsure of efficacy.
struct EmptyUIView: UIViewRepresentable {
    // MARK: - Make UIView

    func makeUIView(context: Context) -> UIView { .init(frame: .zero) }

    // MARK: - Update UIView

    func updateUIView(_ uiView: UIView, context: Context) {}
}

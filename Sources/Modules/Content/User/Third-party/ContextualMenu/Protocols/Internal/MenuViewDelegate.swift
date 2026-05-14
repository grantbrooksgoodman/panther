//
//  MenuViewDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@MainActor
protocol MenuViewDelegate: AnyObject {
    func dismissMenuView(menuView: MenuView, uponTapping menuElement: MenuElement)
}

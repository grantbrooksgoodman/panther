//
//  RootNavigationCoordinator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum RootPage {
    case sample
}

public final class RootNavigationCoordinator: ObservableObject {
    // MARK: - Properties

    @Published public private(set) var page: RootPage = .sample

    // MARK: - Methods

    public func setPage(_ page: RootPage) {
        self.page = page
    }
}

//
//  Providers.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

typealias MenuConfigurationProvider = (_ view: UIView) -> ContextMenuConfiguration?
typealias TargetedPreviewProvider = (_ view: UIView) -> UITargetedPreview?

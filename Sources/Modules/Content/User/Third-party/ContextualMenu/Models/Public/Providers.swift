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

public typealias MenuConfigurationProvider = (_ view: UIView) -> ContextMenuConfiguration?
public typealias TargetedPreviewProvider = (_ view: UIView) -> UITargetedPreview?

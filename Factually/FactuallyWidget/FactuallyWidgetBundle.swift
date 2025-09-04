//
//  FactuallyWidgetBundle.swift
//  FactuallyWidget
//
//  Created by Dave Johnstone on 04/09/2025.
//

import WidgetKit
import SwiftUI

@main
struct FactuallyWidgetBundle: WidgetBundle {
    var body: some Widget {
        FactuallyWidget()
        FactuallyWidgetControl()
        FactuallyWidgetLiveActivity()
    }
}

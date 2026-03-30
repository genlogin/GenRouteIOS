//
//  GenRouteApp.swift
//  GenRoute
//
//  Created by duylt on 3/28/26.
//

import SwiftUI
import SwiftData

@main
struct GenRouteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(AppModelContainer.shared)
        }
    }
}

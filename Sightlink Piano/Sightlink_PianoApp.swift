//
//  Sightlink_PianoApp.swift
//  Sightlink Piano
//
//  Created by Frédéric Inthavanh on 2026-08-16.
//

import SwiftUI

@main
struct Sightlink_PianoApp: App {
    private let dependencies: AppDependencies

    init() {
        self.dependencies = AppDependencyFactory.makeProductionDependencies()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}

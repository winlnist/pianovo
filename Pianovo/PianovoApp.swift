//
//  PianovoApp.swift
//  Pianovo
//
//  Created by Frédéric Inthavanh on 2026-08-16.
//

import SwiftUI

@main
struct PianovoApp: App {
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

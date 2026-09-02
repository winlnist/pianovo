//
//  ContentView.swift
//  Sightlink Piano
//
//  Created by Frédéric Inthavanh on 2026-08-16.
//

import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var body: some View {
        AppShellView(dependencies: dependencies)
    }
}

#Preview {
    ContentView(dependencies: .preview())
}

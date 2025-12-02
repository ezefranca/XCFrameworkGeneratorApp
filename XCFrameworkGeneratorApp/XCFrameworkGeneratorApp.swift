//
//  XCFrameworkGeneratorApp.swift
//  XCFrameworkGeneratorApp
//
//  Created by Ezequiel dos Santos on 27/11/2025.
//

import SwiftUI

@main
struct XCFrameworkGeneratorApp: App {
    @StateObject private var viewModel = GeneratorViewModel(xcodeProjService: XcodeProjService())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

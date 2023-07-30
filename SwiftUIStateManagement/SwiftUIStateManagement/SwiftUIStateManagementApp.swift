//
//  SwiftUIStateManagementApp.swift
//  SwiftUIStateManagement
//
//  Created by Vera Dias on 23/07/2023.
//

import SwiftUI

@main
struct SwiftUIStateManagementApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(state: AppState())
        }
    }
}

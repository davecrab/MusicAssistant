//
//  MusicAssistantApp.swift
//  MusicAssistant
//
//  Created by Dave Crabtree on 2025-12-25.
//

import SwiftUI

@main
struct MusicAssistantApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
